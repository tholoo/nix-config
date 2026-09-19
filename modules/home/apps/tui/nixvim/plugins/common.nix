{ ... }:
{
  plugins = {
    blink-cmp = {
      enable = true;
      settings = {
        keymap.preset = "default";
        completion = {
          list.selection.preselect = false;
          documentation = {
            auto_show = true;
            auto_show_delay_ms = 250;
          };
          menu.border = "rounded";
        };
        signature.enabled = true;
        cmdline.enabled = false;
      };
    };
    fzf-lua = {
      enable = true;
      settings = {
        files = {
          hidden = true;
          follow = false;
        };
        buffers = {
          sort_lastused = true;
          ignore_current_buffer = true;
        };
      };
    };
    mini = {
      enable = true;
      mockDevIcons = true;
      modules = {
        icons = { };
        statusline = { };
        pairs = { };
        ai.n_lines = 100;
        surround.mappings = {
          add = "gsa";
          delete = "gsd";
          replace = "gsr";
          find = "gsf";
          find_left = "gsF";
          highlight = "gsh";
          update_n_lines = "gsn";
        };
      };
    };
    lazygit.enable = true;
    gitsigns = {
      enable = true;
      settings = {
        current_line_blame = false;
        update_debounce = 200;
      };
    };
    which-key = {
      enable = true;
      settings = {
        delay = 400;
        preset = "classic";
        spec = [
          {
            __unkeyed-1 = "<leader>b";
            group = "buffers";
          }
          {
            __unkeyed-1 = "<leader>c";
            group = "code";
          }
          {
            __unkeyed-1 = "<leader>f";
            group = "find";
          }
          {
            __unkeyed-1 = "<leader>g";
            group = "git";
          }
          {
            __unkeyed-1 = "<leader>u";
            group = "toggles";
          }
        ];
      };
    };
    yazi = {
      enable = true;
      settings = {
        open_for_directories = true;
        floating_window_scaling_factor = 1.0;
        yazi_floating_window_border = "none";
        keymaps.open_file_in_tab = false;
      };
    };
    render-markdown = {
      enable = true;
      settings = {
        render_modes = [
          "n"
          "c"
        ];
        # Preserve Stylix's code-span color when Markdown is rendered.
        code.highlight_inline = "@markup.raw.markdown_inline";
        sign.enabled = false;
      };
    };
  };
}
