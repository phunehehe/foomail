#!/usr/bin/env bash
set -efuxo pipefail

nix_build='nix-build --no-out-link'
PATH=$($nix_build '<nixpkgs>' --attr nix)/bin

run_casperjs() {

  # This will become just casperjs after the next NixOS release
  PATH=$($nix_build --expr '
    let inherit (import <nixpkgs> {}) pkgs;
    in pkgs.callPackage ./casperjs {
      inherit (pkgs.texFunctions) fontsConf;
      nodePackages = pkgs.nodePackages // {
        eslint = pkgs.callPackage ./eslint {};
      };
    }
  ')/bin:$PATH

  casperjs test test/spec.js
}

run_eslint() {

  # This will become just nodePackages.eslint after the next NixOS release
  PATH=$($nix_build --expr '
    let inherit (import <nixpkgs> {}) pkgs;
    in pkgs.callPackage ./eslint {}
  ')/bin:$PATH

  eslint static/js/main.js test/spec.js
}

run_hspec() {
  # This conveniently has `cabal test` baked in
  $nix_build --expr '
    let inherit (import <nixpkgs> {}) pkgs;
    in pkgs.callPackage ./package.nix {}
  '
}

run_all() {
  run_casperjs
  run_eslint
  run_hspec
}

run_"${1:-all}"
