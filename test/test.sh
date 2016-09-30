#!/usr/bin/env bash
set -efuxo pipefail

nix_build='nix-build --no-out-link'
PATH=$($nix_build '<nixpkgs>' --attr nix)/bin

run_casperjs() {
  "$($nix_build --expr '
    (import <nixpkgs> {}).casperjs
  ')/bin/casperjs" test test/spec.js --verbose
}

run_eslint() {
  "$($nix_build --expr '
    (import <nixpkgs> {}).nodePackages.eslint
  ')/bin/eslint" static/js/main.js test/spec.js
}

run_hspec() {
  # This conveniently has `cabal test` baked in
  $nix_build --expr '
    let inherit (import <nixpkgs> {}) pkgs;
    in pkgs.callPackage ./default.nix {}
  '
}

run_all() {
  run_casperjs
  run_eslint
  run_hspec
}

run_"${1:-all}"
