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
      description = "Neovim MCP with workspace binding, structured tour loading and buffer snapshots";
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
    cp ${./editor_tools.py} editor_tools.py
    cp ${./prompt_snapshot.py} prompt_snapshot.py
    cp ${./prompt_snapshot.lua} prompt_snapshot.lua
    cp -r ${./tests} tests
    mkdir -p $out/bin
    head -n1 ${lib.getExe upstream} > $out/bin/nvim-mcp
    cat ${./bound.py} >> $out/bin/nvim-mcp
    cp editor_tools.py $out/bin/editor_tools.py
    chmod +x $out/bin/nvim-mcp
    head -n1 ${lib.getExe upstream} > $out/bin/nvim-prompt-snapshot
    cat prompt_snapshot.py >> $out/bin/nvim-prompt-snapshot
    cp prompt_snapshot.lua $out/bin/prompt_snapshot.lua
    chmod +x $out/bin/nvim-prompt-snapshot
    export PYTHONDONTWRITEBYTECODE=1
    export NVIM_TEST=${
      lib.getExe inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.default
    }
    export TOUR_PLUGIN=${pkgs.mine.tour-nvim}
    export MCP_COMMAND=$out/bin/nvim-mcp
    "$interpreter" -m unittest discover -s tests -v
  ''
