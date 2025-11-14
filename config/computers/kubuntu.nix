{ pkgs, ... }:
let
  username = "meow";
in
{
  home = {
    inherit username;
    homeDirectory = "/home/${username}";

    packages = with pkgs; [

    ];

    file = {
      ".local/share/mime/packages/x-logisim.xml".text = ''
        <?xml version="1.0" encoding="UTF-8"?>
        <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
          <mime-type type="application/x-logisim-circuit">
            <comment>Logisim Circuit</comment>
            <glob pattern="*.circ" />
          </mime-type>
        </mime-info>
      '';
    };
  };
  programs.bash.shellAliases = {
    nixup_currentflake = "echo -n kubuntu";
  };
}
