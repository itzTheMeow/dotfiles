{ pkgs, xelib, ... }:
let
  # patch the repo to add the frontmatter to the review.txt file
  # this is kind of hacky and stupid but im trying to keep it pure...
  review =
    (pkgs.applyPatches {
      name = "opencode-review";
      src = pkgs.fetchFromGitHub {
        owner = "Kilo-Org";
        repo = "kilocode";
        rev = "46bd29d733d69545de60a5100997512756ad61b3";
        hash = "sha256-x/WGGJpGi7LGIJE0UmwD2JWuy1ub0yPnPumIrnEFrzE=";
      };
      patches = [ ./add-frontmatter.patch ];
    })
    + "/packages/opencode/src/kilocode/review/review.txt";
in
{
  home-manager.importUser = [
    (_: {
      programs.opencode = {
        enable = true;
        # TODO:26.11 use regular nixpkgs opencode
        package = pkgs.unstable.opencode;
        extraPackages = with pkgs; [
          # mcp servers
          mcp-nixos
          playwright-mcp
        ];
        context = ./AGENTS.md;
        commands.review-full = builtins.readFile review;
        settings = {
          permission.external_directory = {
            "/nix/store/**" = "allow";
            "/tmp/*" = "allow";
            "/z/cache/*" = "allow";
          };
          provider.open-webui = {
            name = xelib.apps.open-webui.name;
            npm = "@ai-sdk/openai-compatible";
            options.baseURL = "${xelib.apps.open-webui.url}/api/v1";
            models = {
              "models/gemini-3.5-flash".name = "google.models/gemini-3.5-flash";
              "qwen3:0.6b".name = "qwen3:0.6b";
              "qwen3:14b-q8_0".name = "qwen3:14b-q8_0";
              "qwen3.5:9b-q8_0".name = "qwen3.5:9b-q8_0";
              "qwen3.6:35b-a3b-q4_K_M".name = "qwen3.6:35b-a3b-q4_K_M";
            };
          };
          mcp = {
            nixos = {
              type = "local";
              command = [ "mcp-nixos" ];
              enabled = true;
            };
            playwright = {
              type = "local";
              command = [
                "playwright-mcp"
                "--browser"
                "chromium"
                "--executable-path"
                "/run/current-system/sw/bin/chromium"
                "--headless"
                "--isolated"
                "--viewport-size"
                "1440x900"
              ];
              environment = {
                PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
                PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
              };
              enabled = true;
            };
          };
        };
      };

      # expose opencode as an ACP agent in zed
      programs.zed-editor.userSettings.agent_servers.OpenCode = {
        type = "custom";
        command = "opencode";
        args = [ "acp" ];
      };

      catppuccin.opencode.enable = true;
    })
  ];
}
