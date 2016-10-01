#!/usr/bin/env bash
set -efuxo pipefail

nix_build='nix-build --no-out-link'
PATH=$($nix_build '<nixpkgs>' --attr nix)/bin

find-bin() {
  attr=$1
  command=$2
  bin="$($nix_build '<nixpkgs>' --attr "$attr")/bin/$command"
  [[ -e $bin ]] && echo "$bin"
}


run-casperjs() {
  $(find-bin casperjs casperjs) test test/spec.js --verbose
}

run-eslint() {
  $(find-bin nodePackages.eslint eslint) static/js/main.js test/spec.js
}

run-hlint() {
  $(find-bin haskellPackages.hlint hlint) .
}

run-cabal() {
  # This conveniently has `cabal test` baked in
  $nix_build --expr '
    let inherit (import <nixpkgs> {}) pkgs;
    in pkgs.callPackage ./default.nix {}
  '
}

run-all() {
  run-casperjs
  run-eslint
  run-hlint
  run-cabal
}

"run-${1:-all}"
