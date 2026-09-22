{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation rec {
  pname = "zellij-zextract";
  version = "0.4.0";

  src = fetchurl {
    url = "https://github.com/codingfragments/zellij-zextract/releases/download/v${version}/zextract.wasm";
    hash = "sha256-LnneanEAK2IcBo6kIyuzyuPt9nb/mSjL0+AC22eh/BA=";
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm644 "$src" "$out/zextract.wasm"
    runHook postInstall
  '';

  meta = {
    description = "Extract and act on matches from Zellij pane scrollback";
    homepage = "https://github.com/codingfragments/zellij-zextract";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
