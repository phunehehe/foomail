#!/usr/bin/env bash

set -efux

cd "$(dirname "$0")"

hpack
cabal2nix . > default.nix
cabal2nix --shell . > shell.nix

nix-shell --command 'cabal configure'
cabal build
