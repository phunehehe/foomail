#!/usr/bin/env bash
set -efuo pipefail

for p in cabal2nix cabal-install haskellPackages.hpack
do
  PATH=$(nix-build --no-out-link '<nixpkgs>' --attr $p)/bin:$PATH
done

hpack
cabal2nix --shell . > shell.nix
nix-shell --run 'cabal configure --enable-tests'
cabal test
