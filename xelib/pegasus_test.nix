# Test suite for pegasus.nix collections
# Run with: nix eval --file xelib/pegasus_test.nix
let
  lib = import <nixpkgs/lib>;

  pegasusLib = import ./pegasus-lib.nix { inherit lib; };
  mkCollectionConfig = pegasusLib.mkCollectionConfig;

  # Empty options template with all fields set to null
  emptyOpts = {
    launch = null;
    workdir = null;
    extensions = null;
    files = null;
    regex = null;
    directories = null;
    ignoreExtensions = null;
    ignoreFiles = null;
    ignoreRegex = null;
    shortname = null;
    sortBy = null;
    summary = null;
    description = null;
  };
  t = "\t";

  # Test cases with expected outputs
  tests = [
    {
      name = "Super Nintendo Entertainment System";
      opts = {
        launch = ''snes9x "{file.path}"'';
        extensions = [
          "7z"
          "bin"
          "smc"
          "sfc"
          "fig"
          "swc"
          "mgd"
          "zip"
          "bin"
        ];
        ignoreFiles = [
          "buggygame.bin"
          "duplicategame.bin"
        ];
      };
      expected = ''
        collection: Super Nintendo Entertainment System
        extensions: 7z, bin, smc, sfc, fig, swc, mgd, zip, bin
        ignore-files: buggygame.bin
        ignore-files: duplicategame.bin
        launch: snes9x "{file.path}"
      '';
    }
    {
      name = "Platformer games";
      opts = {
        files = [
          "mario1.bin"
          "mario2.bin"
          "mario3.bin"
        ];
      };
      expected = ''
        collection: Platformer games
        files: mario1.bin
        files: mario2.bin
        files: mario3.bin
      '';
    }
    {
      name = "Multi-game carts";
      opts = {
        regex = ''\d+.in.1'';
      };
      expected = ''
        collection: Multi-game carts
        regex: \d+.in.1
      '';
    }
    {
      name = "multi line";
      opts = {
        description = ''
          this is a long description
          which is a test of the flow strings

          ^ this should be a dot
          if its not.... well
        '';
      };
      expected = ''
        collection: multi line
        description: 
        ${t}this is a long description
        ${t}which is a test of the flow strings
        ${t}.
        ${t}^ this should be a dot
        ${t}if its not.... well
      '';
    }
  ];

  # Run tests
  runTest =
    test:
    let
      generated = mkCollectionConfig test.name (emptyOpts // test.opts);
      passed = generated == test.expected;
    in
    {
      inherit passed;
      name = test.name;
      expected = test.expected;
      generated = generated;
    };

  results = map runTest tests;
  allPassed = lib.all (r: r.passed) results;

  # Format output
  formatResult =
    r:
    if r.passed then
      "✓ ${r.name}"
    else
      "✗ ${r.name}\n  Expected:\n${
        lib.concatStringsSep "\n" (map (line: "    ${line}") (lib.splitString "\n" r.expected))
      }\n  Got:\n${
        lib.concatStringsSep "\n" (map (line: "    ${line}") (lib.splitString "\n" r.generated))
      }";

  summary = lib.concatStringsSep "\n" (map formatResult results);
in
{
  inherit results allPassed summary;
  testCount = lib.length results;
  passedCount = lib.length (lib.filter (r: r.passed) results);
}
