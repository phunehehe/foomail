{ haskellPackages
, runCommand
, spec
, stdenv
, preConfigure ? ""
}:

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

    # hpack needs the source to glob e.g. data-files
    cp --recursive --no-preserve=mode ${src} src

    cp ${hpackFile} src/package.yaml
    (cd src && ${haskellPackages.hpack}/bin/hpack)
    mv src/${name}.cabal $out
  '';

  # Symlinking won't work because GitLab CI doesn't resolve symlinks when
  # creating artifacts
  copyCabalFile = ''
    cp --force ${cabalFile} ${name}.cabal
  '';

  src = runCommand "${name}-src" {} ''
    cp --recursive --no-preserve=mode ${./.} $out
    (cd $out && ${preConfigure})
  '';

in haskellPackages.mkDerivation {

  inherit src;
  pname = name;
  isExecutable = lib.hasAttr "executables" spec;
  isLibrary = lib.hasAttr "library" spec;
  license = lib.licenses.mpl20;
  version = spec.version or "0.0.0";

  executableHaskellDepends = map (d: haskellPackages.${d}) spec.dependencies;
  testHaskellDepends = map (d:
    haskellPackages.${d}
  ) (lib.concatLists (lib.mapAttrsToList (_: t: t.dependencies) spec.tests));

  preConfigure = ''
    ${copyCabalFile}
  '';

  shellHook = copyCabalFile;
}
