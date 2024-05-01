{
  pkgs,
  config,
  flakeSelf,
  ...
}:
{
  config = {
    home.file."./.local/share/nvim/lazy/nvim-treesitter/" = {
      recursive = true;
      source = pkgs.vimPlugins.nvim-treesitter.withAllGrammars;
    };
    programs.neovim = {
      enable = true;
      withPython3 = true;
      withRuby = true;
      withNodeJs = true;
      defaultEditor = true;
      extraPython3Packages =
        ps: with ps; [
          pip
          pynvim
          python-lsp-ruff
          mypy
        ];
      extraPackages = with pkgs; [
        mypy
        ruff
        ruff-lsp
        gitlint
        commitlint
        djlint
        sqlfluff
        dotenv-linter
        fzf
        nodePackages.pyright
        nodePackages.typescript-language-server
        vscode-langservers-extracted
        marksman
        markdownlint-cli
        markdownlint-cli2
        lua-language-server
        stylua
        yaml-language-server
        shfmt
        dockerfile-language-server-nodejs
        hadolint
        biome
        yarn
        prettierd
      ];
      plugins = with pkgs.vimPlugins; [
        LazyVim
        semshi
      ];
    };
    xdg.configFile.nvim = {
      source = ../../../resources/nvim;
      recursive = true;
    };

    # home.file."./.config/nvim/lua/config/options.lua".text = (builtins.readFile ../../resources/nvim/lua/config/options.lua) + ''
    # vim.opt.runtimepath:append("${config.programs.neovim.finalPackage.python3Env}")
    # '';
  };
}
