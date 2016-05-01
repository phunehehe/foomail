#!/usr/bin/env bash
set -efuxo pipefail

export NIX_PATH=nixpkgs=$HOME/.nix-defexpr/channels/nixos-16.03
PATH=$(nix-build --no-out-link '<nixpkgs>' --attr nix)/bin

run_casperjs() {

  # This will become just casperjs after the next NixOS release
  PATH=$(nix-build --no-out-link --expr '
    let inherit (import <nixpkgs> {}) pkgs;
    in pkgs.callPackage ./casperjs {
      inherit (pkgs.texFunctions) fontsConf;
      eslint = pkgs.callPackage ./eslint {};
    }
  ')/bin:$PATH

  casperjs test test/spec.js
}

run_eslint() {

  # This will become just nodePackages.eslint after the next NixOS release
  PATH=$(nix-build --no-out-link --expr '
    let inherit (import <nixpkgs> {}) pkgs;
    in pkgs.callPackage ./eslint {}
  ')/bin:$PATH

  eslint static/js/main.js
}

run_hspec() {
  # This conveniently has `cabal test` baked in
  nix-build --no-out-link --expr '
    let inherit (import <nixpkgs> {}) pkgs;
    in pkgs.callPackage ./package.nix {}
  '
}

run_all() {
  run_casperjs
  run_eslint
  run_hspec
}

run_${1:-all}
