{ host, ... }:
let
  accent = host.accent or "blue";

  # printed to the left of the modules
  logo = ''
    \    /\
     )  ( ')
    (  /  )
     \(__)|
  '';

  # small configs fastfetch shells out to for the colored title + OS line
  titleConfig = {
    logo.type = "none";
    modules = [
      {
        type = "title";
        key = " ";
        format = "{user-name-colored}{at-symbol-colored}{host-name-colored}";
      }
    ];
  };

  osConfig = {
    logo.type = "none";
    modules = [
      {
        type = "os";
        key = " ";
        format = "{name} {version}";
        outputColor = "light_white";
      }
    ];
  };

  settings = {
    logo = {
      source = "~/.config/fastfetch/logo.txt";
      type = "file";
      padding = {
        top = 1;
        left = 2;
        right = 2;
      };
      color."1" = accent;
    };
    display = {
      color = accent;
      separator = ": ";
      bar = {
        width = 10;
        char = {
          elapsed = "▇";
          total = "▇";
        };
        border = {
          left = "";
          right = "";
        };
        color.total = "dim_black";
      };
      size = {
        spaceBeforeUnit = "never";
        ndigits = 1;
      };
      percent.type = [
        "num"
        "num-color"
        "bar"
      ];
    };
    modules = [
      {
        type = "command";
        key = " ";
        text = "echo $(fastfetch -c ~/.config/fastfetch/config-title.json --pipe false --color '${accent}') $(fastfetch -c ~/.config/fastfetch/config-os.json --pipe false --color '${accent}')";
      }
      {
        type = "uptime";
        key = " ";
        format = "up for {formatted}";
        outputColor = "dim_white";
      }
      "break"
      {
        type = "cpuusage";
        key = "CPU";
        format = "{avg} {avg-bar}";
      }
      {
        type = "memory";
        key = "MEM";
        format = "{percentage} {percentage-bar} {#dim_white}{used} / {total}{#}";
      }
      {
        type = "disk";
        key = "DSK";
        folders = [ "/" ];
        format = "{size-percentage} {size-percentage-bar} {#dim_white}{size-used} / {size-total}{#}";
      }
      {
        type = "packages";
        key = "PKG";
        combined = true;
        outputColor = "dim_white";
      }
      "break"
    ];
  };
in
{
  home-manager.importAll = [
    (_: {
      programs.fastfetch = {
        enable = true;
        inherit settings;
      };
      xdg.configFile = {
        "fastfetch/logo.txt".text = logo;
        "fastfetch/config-title.json".text = builtins.toJSON titleConfig;
        "fastfetch/config-os.json".text = builtins.toJSON osConfig;
      };
    })
  ];
}
