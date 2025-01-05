{
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation rec {
  pname = "zellij-monocle";
  name = pname;

  executable = fetchurl {
    url = "https://github.com/imsnif/monocle/releases/download/v0.100.2/monocle.wasm";
    hash = "sha256-TLfizJEtl1tOdVyT5E5/DeYu+SQKCaibc1SQz0cTeSw=";
  };

  phases = [ "installPhase" ]; # Removes all phases except installPhase

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp $executable $out/zellij-monocle.wasm
    runHook postInstall
  '';
}
