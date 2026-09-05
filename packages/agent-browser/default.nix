{
  lib,
  stdenvNoCC,
  makeWrapper,
  python3,
  playwright-mcp,
  playwright-driver,
}:
stdenvNoCC.mkDerivation {
  pname = "agent-browser";
  version = "1.0.0";
  src = lib.cleanSourceWith {
    src = ./.;
    filter = path: type: baseNameOf path != "__pycache__" && !(lib.hasSuffix ".pyc" path);
  };
  nativeBuildInputs = [ makeWrapper ];
  doCheck = true;
  checkPhase = ''
    ${python3}/bin/python -m unittest discover -s tests
  '';
  installPhase = ''
    mkdir -p $out/libexec $out/bin
    cp agent_browser.py $out/libexec/
    makeWrapper ${python3}/bin/python $out/bin/agent-browser \
      --add-flags $out/libexec/agent_browser.py \
      --set AGENT_BROWSER_MCP ${lib.getExe playwright-mcp} \
      --set AGENT_BROWSER_CHROMIUM ${playwright-driver.browsers}/chromium-${playwright-driver.passthru.browsersJSON.chromium.revision}/chrome-linux64/chrome
  '';
  meta = {
    description = "Pinned Playwright MCP with persistent profiles for concurrent agents";
    mainProgram = "agent-browser";
    platforms = lib.platforms.linux;
  };
}
