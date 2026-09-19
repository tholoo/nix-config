{
  lib,
  inputs,
  pkgs,
  runCommand,
}:
let
  upstream = inputs.nvim-mcp.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
runCommand "nvim-mcp-bound"
  {
    meta = {
      description = "Upstream Neovim MCP with optional per-workspace socket binding";
      mainProgram = "nvim-mcp";
      platforms = lib.platforms.linux;
    };
  }
  ''
    # Reuse the exact Python environment of the pinned upstream executable.
    interpreter="$(head -n1 ${lib.getExe upstream})"
    interpreter="''${interpreter#\#!}"
    test -x "$interpreter"
    cp ${./bound.py} bound.py
    cp -r ${./tests} tests
    PYTHONDONTWRITEBYTECODE=1 "$interpreter" -m unittest discover -s tests -v
    mkdir -p $out/bin
    head -n1 ${lib.getExe upstream} > $out/bin/nvim-mcp
    cat ${./bound.py} >> $out/bin/nvim-mcp
    chmod +x $out/bin/nvim-mcp
  ''
