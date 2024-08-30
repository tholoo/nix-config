{
  obsidian = {
    enable = true;
    settings = {
      completion = {
        nvim_cmp = true;
      };
      workspaces = [
        {
          name = "tholos";
          path = "~/syncs/tholos";
        }
      ];
      new_notes_location = "notes_subdir";
      notes_subdir = "Void";
      daily_notes = {
        folder = "Journal";
      };
      note_id_func = # lua
        ''
          function(title)
            local suffix = ""
            if title ~= nil then
              -- If title is given, transform it into valid file name.
              suffix = title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
            else
              -- If title is nil, just add 4 random uppercase letters to the suffix.
              for _ = 1, 4 do
                suffix = suffix .. string.char(math.random(65, 90))
              end
            end
              return suffix
          end
        '';
      templates = {
        folder = "Templates";
        date_format = "%Y-%m-%d";
        time_format = "%H:%M";
        substitutions = { };
      };
      mappings = {
        "<leader>ot" = {
          action = "'<CMD>ObsidianToday<CR>'";
          opts = {
            buffer = true;
            expr = false;
          };
        };

        "<leader>on" = {
          action = "'<CMD>ObsidianNew<CR>'";
          opts = {
            buffer = true;
            expr = false;
          };
        };

        "<leader>oo" = {
          action = "'<CMD>ObsidianFollowLink<CR>'";
          opts = {
            buffer = true;
            expr = false;
          };
        };

        "<leader>os" = {
          action = "'<CMD>ObsidianSearch<CR>'";
          opts = {
            buffer = true;
            expr = false;
          };
        };

        "<leader>oc" = {
          action = "require('obsidian').util.toggle_checkbox";
          opts = {
            buffer = true;
            expr = true;
          };
        };

        "<leader>of" = {
          action = "require('obsidian').util.toggle_checkbox";
          opts = {
            buffer = true;
            expr = true;
          };
        };

        gf = {
          action = "require('obsidian').util.gf_passthrough";
          opts = {
            buffer = true;
            expr = true;
            noremap = false;
          };
        };

        "<cr>" = {
          action = "require('obsidian').util.smart_action()";
          opts = {
            buffer = true;
            expr = true;
          };
        };
      };
    };
  };
}
