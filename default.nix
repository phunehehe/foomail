{ mkDerivation, aeson, base, bytestring, either, HaskellNet
, HaskellNet-SSL, mime, mtl, servant-server, stdenv, text
, transformers, warp
}:
mkDerivation {
  pname = "foomail";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = false;
  isExecutable = true;
  buildDepends = [
    aeson base bytestring either HaskellNet HaskellNet-SSL mime mtl
    servant-server text transformers warp
  ];
  license = stdenv.lib.licenses.mpl20;
}
