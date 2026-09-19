{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.mine.nixvim;
in
{
  options.mine.nixvim = lib.mine.mkEnable config {
    tags = [
      "tui"
      "editor"
    ];
  };

  config = lib.mkIf cfg.enable {
    home.sessionVariables = {
      SUDO_EDITOR = "nvim";
      DIFFPROG = "nvim -d";
      MANPAGER = "nvim +Man!";
    };
    programs.nixvim = {
      enable = true;
      defaultEditor = true;
      # Keep the trial package and the activated editor on the same configuration.
      wrapRc = true;
      impureRtp = false;
      viAlias = true;
      vimAlias = true;
      package = inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.default;
      imports = [
        ./plugins/common.nix
        ./plugins/lsp.nix
        ./plugins/conform.nix
        ./plugins/treesitter.nix
      ];
      # Stylix supplies the full desktop palette through mini.base16.
      globals.mapleader = " ";
      globals.maplocalleader = ",";
      luaLoader.enable = true;
      clipboard.providers.wl-copy.enable = true;
      withPython3 = false;
      withRuby = false;
      withNodeJs = false;
      extraPackages = [
        pkgs.ripgrep
        pkgs.fd
      ];
      dependencies.yazi.package = config.programs.yazi.package;
      extraConfigLua = builtins.readFile ./workflow.lua;

      opts = {
        shell = lib.getExe pkgs.bash;
        number = true;
        relativenumber = true;
        cursorline = true;
        signcolumn = "yes";
        termguicolors = true;
        showmode = false;
        showtabline = 0;
        laststatus = 3;
        cmdheight = 1;
        winborder = "rounded";
        wrap = false;
        breakindent = true;
        scrolloff = 6;
        sidescrolloff = 8;
        splitright = true;
        splitbelow = true;
        splitkeep = "screen";
        ignorecase = true;
        smartcase = true;
        inccommand = "split";
        expandtab = true;
        shiftwidth = 2;
        tabstop = 2;
        smartindent = true;
        undofile = true;
        undolevels = 10000;
        updatetime = 250;
        timeoutlen = 400;
        autoread = true;
        confirm = true;
        clipboard = "unnamedplus";
        mouse = "a";
        virtualedit = "block";
        foldlevel = 99;
        foldlevelstart = 99;
        fillchars.eob = " ";
      };
    };
  };
}
