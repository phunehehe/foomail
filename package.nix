{ haskellPackages, preConfigure, runCommand, spec, stdenv }:

let

  inherit (spec) name;
  inherit (stdenv) lib;

  getVersion = name:
  let
    versionFromGhc = lib.removeSuffix "\n" (builtins.readFile (
      runCommand "${name}-version" {} ''
        ${haskellPackages.ghc}/bin/ghc-pkg field ${name} version --simple-output > $out
      ''));
  in haskellPackages.${name}.version or versionFromGhc;

  dependenciesWithVersions = map (p: "${p} == ${getVersion p}");
  hpackDependencies = {
    dependencies = dependenciesWithVersions spec.dependencies;
    tests = lib.mapAttrs (name: value: {
      dependencies = dependenciesWithVersions value.dependencies;
    }) spec.tests;
  };
  hpack = lib.recursiveUpdate spec hpackDependencies;

  hpackFile = builtins.toFile "package.yaml" (builtins.toJSON hpack);
  cabalFile = runCommand "${name}.cabal" {} ''
    cp ${hpackFile} package.yaml
    ${haskellPackages.hpack}/bin/hpack
    mv ${name}.cabal $out
  '';

  # GitLab CI doesn't seem to resolve symlinks in artifacts
  copyCabalFile = ''
    cp --force ${cabalFile} ${name}.cabal
  '';

in haskellPackages.mkDerivation {

  pname = name;
  isExecutable = lib.hasAttr "executables" spec;
  isLibrary = lib.hasAttr "library" spec;
  license = lib.licenses.mpl20;
  src = ./.;
  version = spec.version or "0.0.0";

  executableHaskellDepends = map (d: haskellPackages.${d}) spec.dependencies;
  testHaskellDepends = map (d:
    haskellPackages.${d}
  ) (lib.concatLists (lib.mapAttrsToList (_: t: t.dependencies) spec.tests));

  preConfigure = ''
    ${preConfigure}
    ${copyCabalFile}
  '';

  shellHook = copyCabalFile;
}
