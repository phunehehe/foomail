{ pkgs ? import <nixpkgs> {} }:

let drv = pkgs.callPackage ./package.nix {

  # # record doesn't work with GHC 8 yet
  haskellPackages = pkgs.haskell.packages.ghc7103;

  preConfigure = ''
    find static -iname '*.min.*' \
    | while read f
      do mv $f ''${f/.min/}
      done
  '';

  spec = {

    name = "foomail";
    license = "MPL-2.0";

    data-files = "static/**/*";
    executables.foomail.main = "Main.hs";
    ghc-options = "-Wall";
    source-dirs = "src";

    dependencies = [
      "HaskellNet"
      "HaskellNet-SSL"
      "aeson"
      "base"
      "bytestring"
      "containers"
      "either"
      "mime"
      "record"
      "resource-pool"
      "servant-server"
      "text"
      "time"
      "transformers"
      "warp"
    ];

    tests.spec = {
      main = "Spec.hs";
      dependencies = ["hspec"];
      source-dirs = ["test"];
    };
  };
};

in if pkgs.lib.inNixShell then drv.env else drv
