{
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation rec {
  pname = "zellij-room";
  name = pname;

  executable = fetchurl {
    url = "https://github.com/rvcas/room/releases/download/v1.2.0/room.wasm";
    hash = "sha256-t6GPP7OOztf6XtBgzhLF+edUU294twnu0y5uufXwrkw=";
  };

  phases = [ "installPhase" ]; # Removes all phases except installPhase

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp $executable $out/zellij-room.wasm
    runHook postInstall
  '';
}
