{ eslint ? { outPath = ./.; name = "eslint"; }
, pkgs ? import <nixpkgs> {}
}:
let
  nodePackages = import "${pkgs.path}/pkgs/top-level/node-packages.nix" {
    inherit pkgs;
    inherit (pkgs) stdenv nodejs fetchurl fetchgit;
    neededNatives = [ pkgs.python ] ++ pkgs.lib.optional pkgs.stdenv.isLinux pkgs.utillinux;
    self = nodePackages;
    generated = ./generated.nix;
  };
in rec {
  tarball = pkgs.runCommand "eslint-2.9.0.tgz" { buildInputs = [ pkgs.nodejs ]; } ''
    mv `HOME=$PWD npm pack ${eslint}` $out
  '';
  build = nodePackages.buildNodePackage {
    name = "eslint-2.9.0";
    src = [ tarball ];
    buildInputs = nodePackages.nativeDeps."eslint" or [];
    deps = [ nodePackages.by-spec."chalk"."^1.1.3" nodePackages.by-spec."concat-stream"."^1.4.6" nodePackages.by-spec."debug"."^2.1.1" nodePackages.by-spec."doctrine"."^1.2.1" nodePackages.by-spec."es6-map"."^0.1.3" nodePackages.by-spec."escope"."^3.6.0" nodePackages.by-spec."espree"."3.1.4" nodePackages.by-spec."estraverse"."^4.2.0" nodePackages.by-spec."esutils"."^2.0.2" nodePackages.by-spec."file-entry-cache"."^1.1.1" nodePackages.by-spec."glob"."^7.0.3" nodePackages.by-spec."globals"."^9.2.0" nodePackages.by-spec."ignore"."^3.1.2" nodePackages.by-spec."imurmurhash"."^0.1.4" nodePackages.by-spec."inquirer"."^0.12.0" nodePackages.by-spec."is-my-json-valid"."^2.10.0" nodePackages.by-spec."is-resolvable"."^1.0.0" nodePackages.by-spec."js-yaml"."^3.5.1" nodePackages.by-spec."json-stable-stringify"."^1.0.0" nodePackages.by-spec."lodash"."^4.0.0" nodePackages.by-spec."mkdirp"."^0.5.0" nodePackages.by-spec."optionator"."^0.8.1" nodePackages.by-spec."path-is-absolute"."^1.0.0" nodePackages.by-spec."path-is-inside"."^1.0.1" nodePackages.by-spec."pluralize"."^1.2.1" nodePackages.by-spec."progress"."^1.1.8" nodePackages.by-spec."require-uncached"."^1.0.2" nodePackages.by-spec."shelljs"."^0.6.0" nodePackages.by-spec."strip-json-comments"."~1.0.1" nodePackages.by-spec."table"."^3.7.8" nodePackages.by-spec."text-table"."~0.2.0" nodePackages.by-spec."user-home"."^2.0.0" ];
    peerDependencies = [];
  };
}