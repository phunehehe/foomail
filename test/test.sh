#!/usr/bin/env bash
set -efuxo pipefail

export NIX_PATH=nixpkgs=$HOME/.nix-defexpr/channels/nixos-16.03

NEW_PATH=
for p in nix
do
  NEW_PATH=$(nix-build --no-out-link '<nixpkgs>' --attr $p)/bin:$NEW_PATH
done
PATH=$NEW_PATH

run_hspec() {
  # This conveniently has `cabal test` baked in
  nix-build --no-out-link --expr '
    let inherit (import <nixpkgs> {}) pkgs;
    in pkgs.callPackage ./package.nix {}
  '
}

run_eslint() {

  # This will become just nodePackages.eslint after the next NixOS release
  PATH=$(nix-build --no-out-link --expr '
    let inherit (import <nixpkgs> {}) pkgs;
    in pkgs.callPackage ./eslint {}
  ')/bin:$PATH

  eslint static/js/main.js
}

case ${1:-} in
  eslint) run_eslint;;
  hspec) run_hspec;;
  *)
    run_hspec
    run_eslint;;
esac
