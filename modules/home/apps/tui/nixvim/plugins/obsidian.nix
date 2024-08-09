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
          path = "~/tholos";
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
    };
  };
}
