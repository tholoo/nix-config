{ pkgs, lib, getNixFiles, options, config, ... }: {
  imports = let
    getPlugin = file:
      let importedFile = import file;
      in if builtins.isFunction importedFile then
        importedFile { inherit pkgs lib options config getNixFiles getPlugin; }
      else
        importedFile;

    addNixvim = file:
      let pluginSet = getPlugin file;
      in {
        programs.nixvim = if lib.hasAttr "plugins" pluginSet then
          pluginSet
        else {
          plugins = pluginSet;
        };
      };

  in map addNixvim (getNixFiles ./plugins);

  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    colorschemes.ayu.enable = true;

    # extraPackages = with pkgs; [
    # ];

    luaLoader.enable = true;
    clipboard.providers = { xsel.enable = true; };

    # Highlight and remove extra white spaces
    # highlight.ExtraWhitespace.bg = "red";
    match.ExtraWhitespace = "\\s\\+$";

    globals.mapleader = " ";

    options = {
      number = true;
      relativenumber = true;
      shiftwidth = 2;
      tabstop = 2;
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
    ];
  };
}
