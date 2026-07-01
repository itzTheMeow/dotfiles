{
  host,
  hostname,
  pkgs,
  xelib,
  xelpkgs,
  ...
}@inputs:
let
  # hosts that should have less games
  minimalGamesHosts = [ "flynn" ];
  # specific games to include for "minimal" installs
  minimalGames = [ "pvz-fusion" ];

  dir = builtins.readDir ./.;
  gameDirs = builtins.filter (
    name:
    dir.${name} == "directory"
    && (!(builtins.elem hostname minimalGamesHosts) || builtins.elem name minimalGames)
  ) (builtins.attrNames dir);

  winebin = "${pkgs.wineWow64Packages.staging}/bin/wine";
  wineprefix = ".wine";
  wineprefixAbsolute = "/home/${host.username}/${wineprefix}";
in
{
  # enable steam
  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      # steam needs access to the cursor theme
      extraPkgs = _: [ xelib.globals.cursors.package ];
    };
  };
  # set global wineprefix for clarity
  environment.variables.WINEPREFIX = wineprefixAbsolute;
  # create user folder
  systemd.tmpfiles.rules = [
    "d ${wineprefixAbsolute}/user 0755 ${host.username} users -"
  ];

  home-manager.users.${host.username} = hm: {
    # link in the wine prefix files
    home.file = {
      "${wineprefix}/drive_c" = {
        source = "${xelpkgs.wine-prefix}/drive_c";
        recursive = true;
      };
      "${wineprefix}/drive_c/users/${host.username}" = {
        source = hm.config.lib.file.mkOutOfStoreSymlink "${wineprefixAbsolute}/user";
      };
      # set up drives
      "${wineprefix}/dosdevices/c:".source =
        hm.config.lib.file.mkOutOfStoreSymlink "${wineprefixAbsolute}/drive_c";
      "${wineprefix}/dosdevices/z:".source = hm.config.lib.file.mkOutOfStoreSymlink "/";
    };
    # this updates wine with the new prefix only when it changes
    home.activation.updateWinePrefix = hm.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      stateFile="${wineprefixAbsolute}/.wine-state"
      currentState="${xelpkgs.wine-prefix}"
      savedState=""

      if [ -f "$stateFile" ]; then
        savedState=$(cat "$stateFile")
      fi

      if [ "$currentState" != "$savedState" ]; then
        ${pkgs.xvfb-run}/bin/xvfb-run -a ${pkgs.bash}/bin/bash -c ${pkgs.writeScript "updateWinePrefix" ''
          export WINEDEBUG="-all" # disable debugging
          export WINEDLLOVERRIDES="mscoree=n" # disable mono popup

          # initial update
          ${winebin}boot -u
          ${winebin}server -w

          # register any DLLs that didnt get registered on the 32 bit system
          for dll in mmdevapi.dll wbemprox.dll; do
            ${winebin} 'C:\windows\syswow64\regsvr32.exe' /s $dll
          done

          # register the dotnet version
          ${winebin} regedit ${pkgs.writeText "setup.reg" ''
            Windows Registry Editor Version 5.00

            [HKEY_LOCAL_MACHINE\Software\dotnet\Setup\InstalledVersions\x64\sharedhost]
            "Path"="C:\\Program Files\\dotnet\\"
            "Version"="${builtins.head (builtins.attrNames (builtins.readDir "${xelpkgs.wine-prefix}/drive_c/Program Files/dotnet/shared/Microsoft.NETCore.App"))}"
          ''}
          ${winebin}server -w
        ''}
        echo "$currentState" > "$stateFile"
      fi
    '';

    # manage pegasus-frontend
    programs.pegasus-frontend = {
      enable = true;
      package = xelpkgs.pegasus-frontend;
      theme = {
        package = xelpkgs.pegasus-theme-gameos-fire-skye;
        settings = {
          "Allow video thumbnails" = "No";
          "Always show titles" = "No";
          "Blur Background" = "Yes";
          "Collection 1 - Thumbnail" = "Tall";
          "Collection 1" = "Recently Launched";
          "Collection 2 - Thumbnail" = "Tall";
          "Collection 2" = "Favorites";
          "Collection 3 - Thumbnail" = "Tall";
          "Collection 3" = "Most Time Spent";
          "Collection 4 - Thumbnail" = "Tall";
          "Collection 4" = "Randomly Picked";
          "Default to full details" = "Yes";
          "Enable mouse hover" = "No";
          "Game Background" = "Screenshot";
          "Game Logo" = "Show";
          "Hide button help" = "Yes";
          "Randomize Background" = "Yes";
          "Show scanlines" = "No";
          "Use posters for grid" = "Yes";
          "Video preview" = "No";
        };
      };
      enableProviders = [
        "pegasus_media"
        "steam"
      ];
      keybinds = {
        accept = "Return,Enter,GamepadA,Select";
        cancel = "Esc,Backspace,GamepadB,Back";
        menu = "F1,GamepadStart,Menu";
      };

      collections."PC" = {
        shortname = "nix";
      };
      games = map (name: import ./${name}/default.nix inputs) gameDirs;
    };
  };
}
