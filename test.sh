#!/usr/bin/env bash
set -efuxo pipefail

export NIX_PATH=nixpkgs=$HOME/.nix-defexpr/channels/nixos-16.03

# This will become just nodePackages.eslint after the next NixOS release
NEW_PATH=$(nix-build --no-out-link --expr '
  let inherit (import <nixpkgs> {}) pkgs;
  in pkgs.callPackage ./eslint {}
')/bin

for p in nix
do
  NEW_PATH=$(nix-build --no-out-link '<nixpkgs>' --attr $p)/bin:$NEW_PATH
done
PATH=$NEW_PATH

# This conveniently has `cabal test` baked in
nix-build --no-out-link --expr '
  let inherit (import <nixpkgs> {}) pkgs;
  in pkgs.callPackage ./package.nix {}
'

eslint static/js/main.js
