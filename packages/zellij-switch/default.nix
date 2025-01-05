{
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation rec {
  pname = "zellij-switch";
  name = pname;

  executable = fetchurl {
    url = "https://github.com/mostafaqanbaryan/zellij-switch/releases/download/v0.1.1/zellij-switch.wasm";
    hash = "sha256-jLzpmFzzNL3m5q8u4fgB+NOti5nAPOpaESAhEaxTm5E";
  };

  phases = [ "installPhase" ]; # Removes all phases except installPhase

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp $executable $out/zellij-switch.wasm
    runHook postInstall
  '';
}
