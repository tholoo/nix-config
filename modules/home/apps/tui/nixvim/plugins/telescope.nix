{
  telescope = {
    enable = true;

    keymaps = {
      # Find files using Telescope command-line sugar.
      "<leader><leader>" = "git_files";
      "<leader>fg" = "live_grep";
      "<leader>fb" = "buffers";
      "<leader>fh" = "help_tags";
      "<leader>fd" = "diagnostics";

      "<leader>ff" = "find_files";

      # find recent
      "<leader>fr" = "oldfiles";
      "<leader>fR" = "resume";
      "<C-f>" = "live_grep";
    };

    keymapsSilent = true;

    extensions = {
      frecency.enable = true;
      fzf-native.enable = true;
      undo.enable = true;
    };

    settings.defaults = {
      file_ignore_patterns = [
        "^.git/"
        "^.mypy_cache/"
        "^__pycache__/"
        "^output/"
        "^data/"
        "%.ipynb"
      ];
      set_env.COLORTERM = "truecolor";
      layout_strategy = "horizontal";
      layout_config = {
        prompt_position = "top";
      };
      sorting_strategy = "ascending";
      winblend = 0;
    };
  };
}
