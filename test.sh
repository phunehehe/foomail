#!/usr/bin/env bash
set -efuo pipefail
nix-build --no-out-link --expr '
  let inherit (import <nixpkgs> {}) pkgs;
  in pkgs.callPackage ./package.nix {}
'
