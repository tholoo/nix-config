{
  lib,
  buildNpmPackage,
  esbuild,
  python3,
}:
buildNpmPackage {
  pname = "pi-extensions";
  version = "1.0.0";
  src = ./.;
  npmDepsHash = "sha256-kmakGZnJF7pdD1XiUs7qfgkzacKWAqKZrDDuwdh/Zog=";
  npmFlags = [ "--legacy-peer-deps" ];
  npmInstallFlags = [ "--ignore-scripts" ];
  nativeBuildInputs = [
    esbuild
    python3
  ];
  buildPhase = ''
    runHook preBuild
    python compile.py node_modules ${lib.getExe esbuild}
    runHook postBuild
  '';
  # Pi supplies its own SDK aliases. Installing peer copies here gives
  # extensions a second runtime and breaks shared provider registration.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/pi-extensions
    cp -r node_modules $out/lib/pi-extensions/
    runHook postInstall
  '';
  meta = {
    description = "Locked MCP, web, subagent, process and goal extensions for Pi";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
