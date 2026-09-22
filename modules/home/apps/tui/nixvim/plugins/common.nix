{ ... }:
{
  plugins = {
    # LuaSnip supports the collection's nested placeholders (e.g. Python ase).
    friendly-snippets.enable = true;
    luasnip = {
      enable = true;
      fromVscode = [ { } ];
    };
    blink-cmp = {
      enable = true;
      settings = {
        snippets.preset = "luasnip";
        keymap = {
          preset = "default";
          "<Tab>" = [
            # Typing in a placeholder can reopen completion; keep Tab jumping.
            "snippet_forward"
            "accept"
            "fallback"
          ];
        };
        completion = {
          list.selection = {
            preselect = true;
            auto_insert = false;
          };
          documentation = {
            auto_show = true;
            auto_show_delay_ms = 250;
          };
          menu.border = "rounded";
        };
        signature.enabled = true;
        cmdline = {
          enabled = true;
          completion = {
            menu.auto_show = true;
            list.selection = {
              preselect = false;
              auto_insert = false;
            };
          };
        };
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
        jump2d = {
          spotter.__raw = ''require("mini.jump2d").builtin_opts.word_start.spotter'';
          mappings.start_jumping = "<CR>";
          allowed_windows.not_current = false;
          allowed_lines = {
            blank = false;
            fold = false;
          };
          view = {
            dim = true;
            n_steps_ahead = 2;
          };
        };
        ai = {
          n_lines = 100;
          custom_textobjects = {
            f.__raw = ''
              function(ai_type, id, opts)
                -- A containing function can extend beyond the usual neighborhood.
                opts.n_lines = vim.api.nvim_buf_line_count(0)
                return require("mini.ai").gen_spec.treesitter({
                  a = "@function.outer", i = "@function.inner",
                })(ai_type, id, opts)
              end
            '';
            # Preserve mini.ai's function-call object under uppercase F.
            F.__raw = ''require("mini.ai").gen_spec.function_call()'';
          };
        };
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
    render-markdown = {
      enable = true;
      settings = {
        render_modes = [
          "n"
          "no"
          "c"
        ];
        # Preserve Stylix's code-span color when Markdown is rendered.
        code.highlight_inline = "@markup.raw.markdown_inline";
        sign.enabled = false;
      };
    };
  };
}
