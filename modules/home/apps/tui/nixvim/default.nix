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
        ./plugins/rip-substitute.nix
        (import ./plugins/neotest.nix {
          testPlugins =
            inputs.neovim-nightly-overlay.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.vimPlugins;
        })
        (import ./plugins/lazygit.nix {
          configPath = "${config.xdg.configHome}/lazygit/config.yml";
        })
        (import ./plugins/tour.nix {
          tourPlugin = pkgs.mine.tour-nvim;
        })
        ./plugins/lsp.nix
        ./plugins/conform.nix
        ./plugins/treesitter.nix
      ];
      # Stylix supplies the full desktop palette through mini.base16.
      highlightOverride = {
        # Cover upstream defaults that do not inherit the theme's palette.
        FzfLuaLivePrompt.link = "Special";
        FzfLuaBackdrop.link = "Normal";
        DiagnosticDeprecated = {
          sp = "#${config.lib.stylix.colors.base08}";
          strikethrough = true;
        };
        "@markup.link" = {
          fg = "#${config.lib.stylix.colors.base0D}";
          underline = true;
        };
        "@markup.link.label".link = "@markup.link";
        "@markup.link.url".link = "@markup.link";
      };
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
      # Use the configured Zellij build, including its pane-targeted CLI.
      globals.editor_zellij_command = lib.getExe config.programs.zellij.package;
      extraFiles."lua/editor/zellij-zoom.lua".source = ./zellij-zoom.lua;
      extraFiles."lua/editor/git-diff.lua".source = ./git-diff.lua;
      extraConfigLua = builtins.readFile ./workflow.lua;

      opts = {
        shell = lib.getExe pkgs.bash;
        number = true;
        relativenumber = true;
        cursorline = true;
        signcolumn = "yes";
        termguicolors = true;
        # Our Ghostty RTL build handles bidi and Arabic-script shaping itself.
        # Keep Neovim from shaping the same text a second time.
        termbidi = config.mine.terminal.emulator == "ghostty";
        rightleft = false;
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
