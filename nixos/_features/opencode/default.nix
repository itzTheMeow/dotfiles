{ pkgs-unstable, ... }: {
  #TODO:26.11 swap to regular (also below for home-manager too)
  environment.systemPackages = with pkgs-unstable; [ opencode ];

  persist.ed.home.userDirectories = [
    ".config/opencode"
    #".local/share/opencode"
  ];

  home-manager.importUser = [
    (
      _:
      let
        # patch the repo to add the frontmatter to the review.txt file
        # this is kind of hacky and stupid but im trying to keep it pure...
        review =
          (pkgs-unstable.applyPatches {
            name = "opencode-review";
            src = pkgs-unstable.fetchFromGitHub {
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
        # add a custom command using kilo's prompt for reviews
        home.file.".config/opencode/commands/review-full.md".source = review;
      }
    )
  ];
}
