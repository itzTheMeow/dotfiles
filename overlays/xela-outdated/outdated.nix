# stage 2: looks up the four version columns for every tracked attr and
# assembles the final rows - run with:
#   nix eval --impure --json --expr \
#     'import ./outdated.nix { dir = "/path/to/flake"; data = "/path/merged.json"; }'
# data: { system, hosts, entries = [{ host, name, attr, source, version }] }
{
  dir,
  data,
}:
let
  f = builtins.getFlake dir;
  inherit (f.inputs.nixpkgs) lib;

  lock = builtins.fromJSON (builtins.readFile (dir + "/flake.lock"));
  rootInputs = lock.nodes.${lock.root}.inputs;
  # follow the root node's input mapping - node names can have _2/_3 suffixes
  stableRef = lock.nodes.${rootInputs.nixpkgs}.original.ref or "nixos-unknown";
  unstableRef = lock.nodes.${rootInputs."nixpkgs-unstable"}.original.ref or "nixos-unstable";

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
      stableOurs = verOf stablePkgs attr;
      stableTip = verOf tipStable attr;
      unstableOurs = verOf unstablePkgs attr;
      unstableTip = verOf tipUnstable attr;
      # outdated = the live instance lags the upstream tip of its own branch
      outdated = lib.any (
        l:
        let
          tip =
            if l.source == "unstable" then
              unstableTip
            else if l.source == "stable" then
              stableTip
            else
              null;
        in
        tip != null && l.version != null && lib.versionOlder l.version tip
      ) t.live;
    in
    {
      name = t.name;
      inherit attr outdated;
      inherit
        stableOurs
        stableTip
        unstableOurs
        unstableTip
        ;
      live = t.live;
    }
  ) (lib.naturalSort (builtins.attrNames grouped));
in
{
  inherit stableRef unstableRef;
  inherit (json) hosts system;
  packages = rows;
}
