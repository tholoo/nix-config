{
  telescope = {
    enable = true;

    keymaps = {
      # Find files using Telescope command-line sugar.
      "<leader><leader>" = "find_files";
      "<leader>fg" = "live_grep";
      "<leader>fb" = "buffers";
      "<leader>fh" = "help_tags";
      "<leader>fd" = "diagnostics";

      "<leader>ff" = "git_files";

      # find recent
      "<leader>fr" = "oldfiles";
      "<leader>fR" = "resume";
      "<C-f>" = "live_grep";
    };

    extensions = {
      frecency.enable = true;
      fzf-native.enable = true;
      undo.enable = true;
      live-grep-args.enable = true;
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
