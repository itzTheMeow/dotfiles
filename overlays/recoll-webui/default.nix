final: prev: {
  recoll-webui = final.callPackage (
    {
      lib,
      python3,
    }:
    let
      # nixpkgs' recoll python bindings ship conftree.py only inside the
      # recoll package dir, but rclconfig imports it top-level
      pythonRecoll = python3.pkgs.recoll.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          ln -s recoll/conftree.py $out/${python3.sitePackages}/conftree.py
        '';
      });
    in
    python3.pkgs.buildPythonApplication rec {
      pname = "recollwebui";
      version = "0.1.2";
      pyproject = true;

      build-system = with python3.pkgs; [ poetry-core ];

      # sdist pins waitress <3, nixpkgs ships 3.x
      pythonRelaxDeps = [ "waitress" ];

      # bundled bottle.py imports the cgi module, removed in python 3.13; it is
      # only used for multipart uploads which this UI never performs
      postPatch = ''
        substituteInPlace recollwebui/bottle.py \
          --replace-fail "import base64, cgi, email.utils" "import base64, email.utils"
      '';

      src = python3.pkgs.fetchPypi {
        pname = "recollwebui";
        inherit version;
        hash = "sha256-2avl0E8hDwAMk864i+PGNg0tHGynrLEIJ/nNVHMijpQ=";
      };

      propagatedBuildInputs = [
        pythonRecoll
        python3.pkgs.waitress
      ];

      # sdist ships no tests
      doCheck = false;

      pythonImportsCheck = [ "recollwebui" ];

      meta = {
        description = "Web interface for recoll desktop search";
        homepage = "https://framagit.org/medoc92/recollwebui";
        # no license file upstream; unredistributable in theory, freely
        # distributed in practice (bundled by distros and on PyPI)
        license = lib.licenses.unfree;
        mainProgram = "recollwebui";
      };
    }
  ) { };
}
