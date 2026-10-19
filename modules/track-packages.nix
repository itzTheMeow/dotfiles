# auto-derives the list of directly-used packages for `xela-outdated`
# (overlays/xela-outdated) - nothing here is forced unless something reads
# `trackPackages.derived`, so system builds pay no cost
{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  cfg = config.trackPackages;

  # best-effort pname of a derivation (falls back to name-minus-version)
  drvName =
    pkg:
    if pkg ? pname && lib.isString pkg.pname then
      pkg.pname
    else if pkg ? name && lib.isString pkg.name then
      if pkg ? version && lib.isString pkg.version && lib.hasSuffix "-${pkg.version}" pkg.name then
        lib.removeSuffix "-${pkg.version}" pkg.name
      else
        pkg.name
    else
      null;

  # best-effort string version
  drvVersion =
    pkg:
    let
      v = pkg.version or null;
    in
    if v == null then
      null
    else if lib.isString v then
      v
    else
      toString v;

  # walk a (possibly dotted) attr path into a scope, null anywhere along it
  selectAttr =
    scope: attr:
    lib.foldl' (s: k: if s == null then null else (s.${k} or null)) scope (lib.splitString "." attr);

  # outPath of `scope.<attr>` (dotted paths ok) if it is a derivation, else null
  probe =
    scope: attr:
    let
      r = builtins.tryEval (
        let
          v = selectAttr scope attr;
        in
        if lib.isDerivation v then v.outPath else null
      );
    in
    if r.success then r.value else null;

  # nixpkgs attr for a pname: explicit alias, else the top-level attr, else
  # the kdePackages/qt6 scopes (where KDE gear and Qt live)
  resolveAttr =
    name:
    if cfg.aliases ? ${name} then
      cfg.aliases.${name}
    else if (pkgs.kdePackages or { }) ? ${name} then
      "kdePackages.${name}"
    else if (pkgs.qt6 or { }) ? ${name} then
      "qt6.${name}"
    else
      name;

  # classify where a derivation came from by comparing store paths against
  # the base instance and the `unstable` overlay; unstable is checked first
  # so hosts whose base instance *is* unstable (unstableHosts) classify right
  classify =
    attr: out:
    let
      unstableOut = probe pkgs.unstable attr;
      baseOut = probe pkgs attr;
    in
    if unstableOut != null && unstableOut == out then
      "unstable"
    else if baseOut != null && baseOut == out then
      "stable"
    else
      "other";

  # derivations from `root.<name>.package` where `<name>.enable` is true.
  # the options tree is consulted first so configs with renamed/fragile
  # options (e.g. services.frp aborts on access - uncatchable by tryEval)
  # are never forced
  enabledPackages =
    root: opts:
    lib.concatLists (
      lib.mapAttrsToList (
        name: _:
        let
          # invisible options are rename shims (e.g. services.frp.enable ->
          # instances."".enable); reading their config aborts - skip them
          visible = opt: opt != null && ((opt.visible or true) == true);
          declared =
            (opts ? ${name}) && visible (opts.${name}.enable or null) && visible (opts.${name}.package or null);
          r = builtins.tryEval (
            if declared then (if root.${name}.enable == true then root.${name}.package else null) else null
          );
        in
        lib.optional (r.success && lib.isDerivation r.value) r.value
      ) root
    );

  hmUsers = config.home-manager.users or { };
  hmUserOpts = options.home-manager.users or { };

  # home.packages of every home-manager user
  hmUserPackages =
    let
      r = builtins.tryEval (lib.mapAttrsToList (_: u: u.home.packages or [ ]) hmUsers);
    in
    if r.success then lib.concatLists r.value else [ ];

  # every directly-referenced derivation, from all four sources
  collected = lib.flatten [
    config.environment.systemPackages
    (enabledPackages config.services options.services)
    (enabledPackages config.programs options.programs)
    hmUserPackages
    (lib.concatLists (
      map (
        u:
        enabledPackages ((hmUsers.${u} or { }).programs or { }) ((hmUserOpts.${u} or { }).programs or { })
      ) (builtins.attrNames hmUsers)
    ))
  ];

  # { name, attr, version, out } per collected derivation
  mkEntry =
    pkg:
    let
      r = builtins.tryEval {
        name = drvName pkg;
        version = drvVersion pkg;
        out = pkg.outPath;
      };
    in
    if r.success && r.value.name != null && r.value.out != null then
      [
        {
          inherit (r.value) name version out;
          attr = resolveAttr r.value.name;
        }
      ]
    else
      [ ];

  rankOf =
    source:
    if source == "unstable" then
      2
    else if source == "stable" then
      1
    else
      0;

  # dedupe by name, preferring the unstable instance when a package shows up
  # from both
  merged = lib.foldl' (
    acc: entry:
    let
      prev = acc.${entry.name} or null;
    in
    acc
    // {
      ${entry.name} = if prev == null || rankOf entry.source > rankOf prev.source then entry else prev;
    }
  ) { } (map (e: e // { source = classify e.attr e.out; }) (lib.concatLists (map mkEntry collected)));

  # extra tracked attrs (not reachable from config); live from the base
  # instance
  extraEntry =
    attr:
    let
      base = probe pkgs attr;
      unstableOut = probe pkgs.unstable attr;
      basePkg = selectAttr pkgs attr;
      r = builtins.tryEval {
        name = if lib.isDerivation basePkg then drvName basePkg else null;
        version = if lib.isDerivation basePkg then drvVersion basePkg else null;
      };
    in
    if !r.success || r.value.name == null then
      [
        {
          name = attr;
          inherit attr;
          version = null;
          source = "other";
        }
      ]
    else
      [
        {
          inherit attr;
          name = r.value.name;
          version = r.value.version;
          source =
            if base != null && unstableOut != null && base == unstableOut then "unstable" else "stable";
        }
      ];

  derivedList =
    let
      strip = e: {
        inherit (e)
          name
          attr
          source
          version
          ;
      };
      filtered = map strip (lib.filter (e: !lib.elem e.name cfg.ignore) (lib.attrValues merged));
    in
    filtered ++ lib.concatLists (map extraEntry cfg.extra);
in
{
  options.trackPackages = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "whether to auto-derive the tracked-package list";
    };
    ignore = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "package names to exclude from tracking";
    };
    extra = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "nixpkgs attr names to track even though they are not reachable from config";
    };
    aliases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "pname -> nixpkgs attr name, for packages whose pname differs from the attr";
    };
    derived = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption { type = lib.types.str; };
            attr = lib.mkOption { type = lib.types.str; };
            source = lib.mkOption {
              type = lib.types.enum [
                "stable"
                "unstable"
                "other"
              ];
            };
            version = lib.mkOption { type = lib.types.nullOr lib.types.str; };
          };
        }
      );
      readOnly = true;
      description = "auto-derived tracked packages (lazily evaluated; read by outdated)";
    };
  };

  config.trackPackages.derived = if cfg.enable then derivedList else [ ];
}
