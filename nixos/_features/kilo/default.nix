{ pkgs-unstable, ... }: {
  environment.systemPackages = [
    #TODO:pr https://github.com/NixOS/nixpkgs/issues/542516
    #TODO:26.11 use actual package??
    (pkgs-unstable.kilo.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs-unstable.nodejs_22 ];
      postPatch = (old.postPatch or "") + ''
        substituteInPlace packages/opencode/script/build.ts \
          --replace-fail '      console.log(`Running smoke test: ''${binaryPath} --pure models anthropic`)' \
                         '      console.log("Skipping models snapshot smoke test")' \
          --replace-fail '      await smokeModels(binaryPath)' \
                         '      await Promise.resolve()' \
          --replace-fail '      console.log("Models snapshot smoke test passed")' \
                         '      void 0'
      '';
    }))
  ];

  persist.ed.home.userDirectories = [ ".config/kilo" ];
}
