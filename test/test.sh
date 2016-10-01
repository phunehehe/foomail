#!/usr/bin/env bash
set -efuxo pipefail

nix_build='nix-build --no-out-link'
PATH=$($nix_build '<nixpkgs>' --attr nix)/bin

find-bin() {
  attr=$1
  bin=$($nix_build '<nixpkgs>' --attr "$attr")/bin
  test -e "$bin"
  echo "$bin"
}

find-command() {
  attr=$1
  command=$2
  fullCommand=$(find-bin "$attr")/$command
  test -e "$fullCommand"
  echo "$fullCommand"
}

make-bin-path() {
  path=''
  for a in "$@"
  do
    path=$(find-bin $a):$path
  done
  echo "$path"
}


run-cabal() {

  # This conveniently has `cabal test` baked in
  $nix_build --expr '
    let inherit (import <nixpkgs> {}) pkgs;
    in pkgs.callPackage ./default.nix {}
  '

  # We are just abusing the shell hook to output the cabal file
  PATH=$(make-bin-path bash coreutils nix) nix-shell --run true
}

run-casperjs() {
  $(find-command casperjs casperjs) test test/spec.js --verbose
}

run-eslint() {
  $(find-command nodePackages.eslint eslint) static/js/main.js test/spec.js
}

run-hlint() {
  $(find-command haskellPackages.hlint hlint) .
}


run-all() {
  run-cabal
  run-casperjs
  run-eslint
  run-hlint
}

"run-${1:-all}"
