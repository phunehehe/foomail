with (import <nixpkgs> {}).pkgs;
let pkg = haskellngPackages.callPackage
            ({ mkDerivation, aeson, base, bytestring, containers, either
             , HaskellNet, HaskellNet-SSL, mime, resource-pool, servant-server
             , stdenv, text, transformers, warp
             }:
             mkDerivation {
               pname = "foomail";
               version = "0.1.0.0";
               src = ./.;
               isLibrary = false;
               isExecutable = true;
               buildDepends = [
                 aeson base bytestring containers either HaskellNet HaskellNet-SSL
                 mime resource-pool servant-server text transformers warp
               ];
               license = stdenv.lib.licenses.mpl20;
             }) {};
in
  pkg.env
