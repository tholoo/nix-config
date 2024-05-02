{
  pkgs,
  lib,
  getNixFiles,
  options,
  config,
  ...
}:
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

  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    colorschemes.ayu.enable = true;

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
      incsearch = true;
      termguicolors = true;
      scrolloff = 8;
      signcolumn = "yes";
      updatetime = 50;
      termbidi = true;
      # foldlevelstart = 99;
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
        action = "<CMD>update<CR>";
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
    ];
    extraConfigLua = ''
      vim.api.nvim_set_hl(0, "WinSeparator", {guibg=False})
      -- Disable auto comment next line
      vim.cmd([[autocmd FileType * set formatoptions-=ro]])
      -- change line number coloring
      vim.api.nvim_set_hl(0, "LineNr", { fg = "gray" })
    '';
    extraPlugins = with pkgs.vimPlugins; [ LazyVim ];
  };
}
