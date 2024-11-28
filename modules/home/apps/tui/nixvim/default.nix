{
  inputs,
  pkgs,
  options,
  config,
  lib,
  host,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable getNixFiles;
  cfg = config.mine.${name};
  name = "nixvim";
in
{
  imports =
    let
      getPlugin =
        file:
        let
          importedFile = import file;
        in
        if builtins.isFunction importedFile then
          importedFile {
            inherit
              inputs
              host
              pkgs
              lib
              options
              config
              getNixFiles
              getPlugin
              ;
          }
        else
          importedFile;

      addNixvim =
        file:
        let
          pluginSet = getPlugin file;
        in
        {
          programs.nixvim = if lib.hasAttr "plugins" pluginSet then pluginSet else { plugins = pluginSet; };
        };
    in
    map addNixvim (getNixFiles ./plugins);

  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "editor"
    ];
  };

  config = mkIf cfg.enable {

    home.sessionVariables = {
      EDITOR = "nvim";
      SUDO_EDITOR = "nvim";
      VISUAL = "nvim";
      DIFFPROG = "nvim -d";
      MANPAGER = "nvim +Man!";
    };

    programs.nixvim = {
      enable = true;
      # package = inputs.neovim-nightly-overlay.packages.${pkgs.system}.default;
      defaultEditor = true;
      colorschemes.cyberdream = {
        enable = true;
      };

      # extraPackages = with pkgs; [
      # ];

      luaLoader.enable = true;
      clipboard.providers = {
        xsel.enable = true;
      };

      # Highlight and remove extra white spaces
      # highlight.ExtraWhitespace.bg = "red";
      match.ExtraWhitespace = "\\s\\+$";

      globals = {
        mapleader = " ";
        copilot_proxy = "http://localhost:2080";
      };

      opts = {
        number = true;
        showmode = false; # don't show current mode of cursor in bar
        relativenumber = true;
        shiftwidth = 4;
        tabstop = 4;
        clipboard = [ "unnamedplus" ];
        smartindent = true;
        expandtab = true;
        wrap = false;
        # swapfile = false; #Undotree
        # backup = false; #Undotree
        undofile = true;
        undolevels = 10000;
        incsearch = true;
        termguicolors = true;
        scrolloff = 8;
        signcolumn = "yes";
        updatetime = 50;
        termbidi = true;
        # foldlevelstart = 99;
        smartcase = true;
        ignorecase = true;
        splitright = true; # Put new windows right of current
        virtualedit = "block"; # Allow cursor to move where there is no text in visual block mode
        fillchars = {
          foldopen = "";
          foldclose = "";
          fold = " ";
          foldsep = " ";
          diff = "╱";
          eob = " ";
        };
        smoothscroll = true;
        foldmethod = "expr";
        conceallevel = 2;
        colorcolumn = "120";
      };

      keymaps = [
        {
          key = "<esc>";
          action = ":noh<CR>";
          mode = "n";
          options = {
            silent = true;
            noremap = true;
          };
        }
        {
          key = "<leader>w";
          action = "<CMD>write<CR>";
          options = {
            silent = true;
            noremap = true;
          };
        }
        {
          key = "<C-d>";
          action = "<C-d>zz";
          mode = "n";
          options = {
            silent = true;
            noremap = true;
          };
        }
        {
          key = "<C-u>";
          action = "<C-u>zz";
          mode = "n";
          options = {
            silent = true;
            noremap = true;
          };
        }
        {
          key = "]<Space>";
          action = '':<C-u>put =repeat(nr2char(10),v:count)<Bar>execute "\'[-1"<CR>'';
          mode = "n";
          options = {
            silent = true;
            noremap = true;
          };
        }
        {
          key = "[<Space>";
          action = '':<C-u>put!=repeat(nr2char(10),v:count)<Bar>execute "\']+1"<CR>'';
          mode = "n";
          options = {
            silent = true;
            noremap = true;
          };
        }
        {
          key = "<leader>fu";
          action = ''<CMD>Telescope undo<CR>'';
          mode = "n";
          options = {
            noremap = true;
          };
        }
        # better up/down
        {
          key = "j";
          action = "v:count == 0 ? 'gj' : 'j'";
          mode = [
            "n"
            "x"
          ];
          options = {
            expr = true;
            silent = true;
          };
        }
        {
          key = "<Down>";
          action = "v:count == 0 ? 'gj' : 'j'";
          mode = [
            "n"
            "x"
          ];
          options = {
            expr = true;
            silent = true;
          };
        }
        {
          key = "k";
          action = "v:count == 0 ? 'gk' : 'k'";
          mode = [
            "n"
            "x"
          ];
          options = {
            expr = true;
            silent = true;
          };
        }
        {
          key = "<Up>";
          action = "v:count == 0 ? 'gk' : 'k'";
          mode = [
            "n"
            "x"
          ];
          options = {
            expr = true;
            silent = true;
          };
        }
        # Resize window using <ctrl> arrow keys
        {
          key = "<C-Up>";
          action = "<cmd>resize +2<cr>";
          mode = [ "n" ];
          options = {
            silent = true;
            desc = "Increase Window Height";
          };
        }
        {
          key = "<C-Down>";
          action = "<cmd>resize -2<cr>";
          mode = [ "n" ];
          options = {
            silent = true;
            desc = "Decrease Window Height";
          };
        }
        {
          key = "<C-Left>";
          action = "<cmd>vertical resize -2<cr>";
          mode = [ "n" ];
          options = {
            silent = true;
            desc = "Decrease Window Width";
          };
        }
        {
          key = "<C-Right>";
          action = "<cmd>vertical resize +2<cr>";
          mode = [ "n" ];
          options = {
            silent = true;
            desc = "Increase Window Width";
          };
        }
        # Move Lines
        {
          key = "<A-j>";
          action = "<cmd>m .+1<cr>==";
          mode = [ "n" ];
          options = {
            silent = true;
            desc = "Move Down";
          };
        }
        {
          key = "<A-k>";
          action = "<cmd>m .-2<cr>==";
          mode = [ "n" ];
          options = {
            silent = true;
            desc = "Move Up";
          };
        }
        {
          key = "<A-j>";
          action = "<esc><cmd>m .+1<cr>==gi";
          mode = [ "i" ];
          options = {
            silent = true;
            desc = "Move Down";
          };
        }
        {
          key = "<A-k>";
          action = "<esc><cmd>m .-2<cr>==gi";
          mode = [ "i" ];
          options = {
            silent = true;
            desc = "Move Up";
          };
        }
        {
          key = "<A-j>";
          action = ":m '>+1<cr>gv=gv";
          mode = [ "v" ];
          options = {
            silent = true;
            desc = "Move Down";
          };
        }
        {
          key = "<A-k>";
          action = ":m '<-2<cr>gv=gv";
          mode = [ "v" ];
          options = {
            silent = true;
            desc = "Move Up";
          };
        }
        # buffers
        {
          key = "<S-h>";
          action = "<cmd>bprevious<cr>";
          mode = [ "n" ];
          options = {
            silent = true;
            desc = "Prev Buffer";
          };
        }
        {
          key = "<S-l>";
          action = "<cmd>bnext<cr>";
          mode = [ "n" ];
          options = {
            silent = true;
            desc = "Next Buffer";
          };
        }
        {
          key = "[b";
          action = "<cmd>bprevious<cr>";
          mode = [ "n" ];
          options = {
            silent = true;
            desc = "Prev Buffer";
          };
        }
        {
          key = "]b";
          action = "<cmd>bnext<cr>";
          mode = [ "n" ];
          options = {
            silent = true;
            desc = "Next Buffer";
          };
        }
        {
          key = "<leader>bb";
          action = "<cmd>e #<cr>";
          mode = [ "n" ];
          options = {
            silent = true;
            desc = "Switch to Other Buffer";
          };
        }
        {
          key = "<leader>`";
          action = "<cmd>e #<cr>";
          mode = [ "n" ];
          options = {
            silent = true;
            desc = "Switch to Other Buffer";
          };
        }
        # quickfix
        {
          key = "[q";
          action = "vim.cmd.cprev";
          mode = [ "n" ];
          options = {
            silent = true;
            desc = "Previous Quickfix";
          };
        }
        {
          key = "]q";
          action = "vim.cmd.cnext";
          mode = [ "n" ];
          options = {
            silent = true;
            desc = "Next Quickfix";
          };
        }
        {
          key = "[q";
          action = ''<CMD>cp<CR>'';
          mode = "n";
          options = {
            noremap = true;
          };
        }
        {
          key = "]q";
          action = ''<CMD>cn<CR>'';
          mode = "n";
          options = {
            noremap = true;
          };
        }
        {
          key = "<leader>\\r";
          action = ''<CMD>CellularAutomaton make_it_rain<CR>'';
          mode = "n";
          options = {
            noremap = true;
          };
        }
      ];
      extraConfigLua = ''
        vim.api.nvim_set_hl(0, "WinSeparator", {guibg=False})
        -- Disable auto comment next line
        vim.cmd([[autocmd FileType * set formatoptions-=ro]])
        -- change line number coloring
        vim.api.nvim_set_hl(0, "LineNr", { fg = "gray" })

        require('eyeliner').setup({
          highlight_on_key = true
        })

        if vim.g.started_by_firenvim == true then
          vim.o.laststatus = 0
        else
          vim.o.laststatus = 2
        end


        require("conform").setup({
          format_on_save = function(bufnr)
            -- Disable with a global or buffer-local variable
            if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
              return
            end
            return { timeout_ms = 500, lsp_format = "fallback" }
          end,
        })

        vim.api.nvim_create_user_command("FormatDisable", function(args)
          if args.bang then
            -- FormatDisable! will disable formatting just for this buffer
            vim.b.disable_autoformat = true
          else
            vim.g.disable_autoformat = true
          end
        end, {
          desc = "Disable autoformat-on-save",
          bang = true,
        })

        vim.api.nvim_create_user_command("FormatEnable", function()
          vim.b.disable_autoformat = false
          vim.g.disable_autoformat = false
        end, {
          desc = "Re-enable autoformat-on-save",
        })

        -- Toggle function
        local function toggle_format()
          if vim.g.disable_autoformat or vim.b.disable_autoformat then
            vim.g.disable_autoformat = false
            vim.b.disable_autoformat = false
            print("Autoformat enabled")
          else
            vim.g.disable_autoformat = true
            vim.b.disable_autoformat = true
            print("Autoformat disabled")
          end
        end


        -- Map to <leader>Ft
        vim.api.nvim_set_keymap("n", "<leader>Ft", ":lua toggle_format()<CR>", { noremap = true, silent = true })

      '';
      extraPlugins = with pkgs.vimPlugins; [
        LazyVim
        vim-unimpaired
        webapi-vim
        eyeliner-nvim
        cellular-automaton-nvim
        # himalaya-vim
        pkgs.mine.processing-vim
        asyncrun-vim
      ];
      extraPackages = with pkgs; [
        rustfmt
        rustc
        cargo
        lldb
        shfmt
        shellcheck
      ];
      performance = {
        byteCompileLua.enable = true;
        combinePlugins = {
          enable = true;
          standalonePlugins = with pkgs.vimPlugins; [
            nvim-treesitter
            nvim-treesitter-textobjects
            hmts-nvim
            neovim-ayu
            LazyVim
            copilot-vim
            copilot-lua
            yanky-nvim
            firenvim
            conform-nvim
            himalaya-vim
            neotest
            neotest-python
            neotest-golang
            onedark-nvim
          ];
        };
      };
    };
  };
}
