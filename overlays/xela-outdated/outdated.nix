# stage 2: looks up the version columns for every tracked attr and assembles
# the final rows - run with:
#   nix eval --impure --json --expr \
#     'import ./outdated.nix { dir = "/path/to/flake"; data = "/path/merged.json"; }'
# data: { system, hosts, entries = [{ host, name, attr, source, version }] }
{
  dir,
  data,
  # pass nextSrc to get the NEXT column: a tarball URL (the next release
  # branch, resolved by the wrapper script) or "unstable" (fallback until the
  # next branch is cut). leave it off to skip that column entirely.
  nextSrc ? null,
}:
let
  f = builtins.getFlake dir;
  inherit (f.inputs.nixpkgs) lib;

  lock = builtins.fromJSON (builtins.readFile (dir + "/flake.lock"));
  rootInputs = lock.nodes.${lock.root}.inputs;
  # follow the root node's input mapping - node names can have _2/_3 suffixes
  stableRef = lock.nodes.${rootInputs.nixpkgs}.original.ref or "nixos-unknown";
  unstableRef = lock.nodes.${rootInputs."nixpkgs-unstable"}.original.ref or "nixos-unstable";

  # the release *after* the current stable: nixos-26.05 -> nixos-26.11,
  # nixos-26.11 -> nixos-27.05; null when the ref is not a release branch
  nextRef =
    let
      m = builtins.match "nixos-([0-9]{2})\\.([0-9]{2})" stableRef;
      yy = if m == null then "" else builtins.elemAt m 0;
      mm = if m == null then "" else builtins.elemAt m 1;
      nextYy =
        if m == null then "" else (if (lib.toInt yy) < 9 then "0" else "") + toString ((lib.toInt yy) + 1);
    in
    if m == null then
      null
    else if mm == "05" then
      "nixos-${yy}.11"
    else if mm == "11" then
      "nixos-${nextYy}.05"
    else
      null;

  json = builtins.fromJSON (builtins.readFile data);
  system = json.system;

  mkPkgs =
    input:
    import input.outPath {
      inherit system;
      config.allowUnfree = true;
    };

  # our locked revisions
  stablePkgs = mkPkgs f.inputs.nixpkgs;
  unstablePkgs = mkPkgs f.inputs.nixpkgs-unstable;

  # upstream channel tips (fetched at runtime; cached by fetchTarball)
  tipStable = import (fetchTarball "https://channels.nixos.org/${stableRef}/nixexprs.tar.xz") {
    inherit system;
    config.allowUnfree = true;
  };
  tipUnstable = import (fetchTarball "https://channels.nixos.org/${unstableRef}/nixexprs.tar.xz") {
    inherit system;
    config.allowUnfree = true;
  };

  # tip for the NEXT column (only when nextSrc is passed): the next release
  # branch tarball when the wrapper resolved one, else the nixos-unstable tip
  # (the closest known preview until the branch is cut). Every package branch
  # compares against this instance.
  tipNext =
    if nextSrc == null then
      null
    else if nextSrc == "unstable" then
      tipUnstable
    else
      import (fetchTarball nextSrc) {
        inherit system;
        config.allowUnfree = true;
      };
  nextSource =
    if nextSrc == null then
      null
    else if nextSrc == "unstable" then
      unstableRef
    else
      "branch";

  # walk a (possibly dotted) attr path into a scope, null anywhere along it
  selectAttr =
    scope: attr:
    lib.foldl' (s: k: if s == null then null else (s.${k} or null)) scope (lib.splitString "." attr);

  # string version of `<pkgs>'.<attr>`, null when missing/unresolvable
  verOf =
    pkgs': attr:
    let
      r = builtins.tryEval (
        let
          v = selectAttr pkgs' attr;
        in
        if !(lib.isDerivation v) then
          null
        else if v ? version && lib.isString v.version then
          v.version
        else
          null
      );
    in
    if r.success then r.value else null;

  # group entries across hosts: attr -> { name, live = [{ host version source }] }
  grouped = lib.foldl' (
    acc: e:
    let
      cur =
        acc.${e.attr} or {
          name = e.name;
          live = [ ];
        };
    in
    acc
    // {
      ${e.attr} = cur // {
        live = cur.live ++ [
          {
            inherit (e) host version source;
          }
        ];
      };
    }
  ) { } json.entries;

  rows = map (
    attr:
    let
      t = grouped.${attr};
      # one branch per package: unstable only when explicitly pinned from
      # pkgs.unstable (on any host), stable otherwise
      branch =
        if lib.any (l: l.source == "unstable") t.live then
          "unstable"
        else if lib.any (l: l.source == "stable") t.live then
          "stable"
        else
          "other";
      oursPkgs = if branch == "unstable" then unstablePkgs else stablePkgs;
      tipPkgs = if branch == "unstable" then tipUnstable else tipStable;
      liveVer = (builtins.head t.live).version;
      ours = if branch == "other" then liveVer else verOf oursPkgs attr;
      tip = if branch == "other" then null else verOf tipPkgs attr;
      # NEXT (only when nextSrc is passed): version in the next release /
      # release preview. Unstable pins show n/a while the next branch is not
      # cut - the fallback instance is the unstable tip, which their TIP
      # column already shows.
      next =
        if nextSrc == null then
          null
        else if nextSrc == "unstable" && branch == "unstable" then
          null
        else
          verOf tipNext attr;
      outdated = ours != null && tip != null && lib.versionOlder ours tip;
      nextChanged = ours != null && next != null && lib.versionOlder ours next;
    in
    {
      name = t.name;
      inherit
        attr
        branch
        ours
        tip
        next
        nextChanged
        outdated
        ;
      live = map (l: l.host) t.live;
    }
  ) (lib.naturalSort (builtins.attrNames grouped));
in
{
  inherit
    stableRef
    unstableRef
    nextRef
    nextSource
    ;
  inherit (json) hosts system;
  packages = rows;
}
