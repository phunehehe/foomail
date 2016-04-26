{ stdenv, fetchFromGitLab, cabal2nix, haskellPackages, nodePackages }:
let
  src = stdenv.mkDerivation {
    src = ./.;
    name = "foomail";
    buildInputs = [
      cabal2nix
      haskellPackages.hpack
      nodePackages.coffee-script
    ];
    installPhase = ''
      cp --no-preserve=mode --recursive $src $out
      cd $out
      coffee --compile static/coffee/*.coffee
      find static -iname '*.min.*' \
      | while read f
        do mv $f ''${f/.min/}
        done
      hpack
      cabal2nix . > default.nix
    '';
  };
in haskellPackages.callPackage "${src}/default.nix" {}
