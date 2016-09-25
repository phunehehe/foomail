{ cabal2nix
, callPackage
, haskellPackages
, stdenv
}:

let

  src = stdenv.mkDerivation {

    src = ./.;
    name = "foomail";

    buildInputs = [
      cabal2nix
      haskellPackages.hpack
    ];

    installPhase = ''
      cp --no-preserve=mode --recursive $src $out
      cd $out
      find static -iname '*.min.*' \
      | while read f
        do mv $f ''${f/.min/}
        done
      hpack
      cabal2nix --shell . > shell.nix
    '';
  };

in callPackage "${src}/shell.nix" {
  # record doesn't work with GHC 8 yet
  compiler = "ghc7103";
}
