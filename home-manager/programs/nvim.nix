{ pkgs, config, ... }: {
  # config.home.file."./.local/share/nvim/my-local-lazy/nvim-treesitter/" = {
    # recursive = true;
    # source = pkgs.vimPlugins.nvim-treesitter.withAllGrammars;
  # };
  # programs.neovim = {
    # enable = true;
    # withPython3 = true;
    # withRuby = true;
    # withNodeJs = true;
    # defaultEditor = true;
    # extraPython3Packages = pyPkgs: with pyPkgs; [ pynvim python-lsp-ruff mypy ];
  # };
  # xdg.configFile.nvim = {
    # source = config.lib.file.mkOutOfStoreSymlink "/home/tholo/nix-config/resources/nvim";
    # recursive = true;
  # };
}
