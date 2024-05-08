{ pkgs, lib, ... }:
let
  # TODO: somehow patch glow in init.lua with lib.getExe pkgs.glow
  glow-plugin = pkgs.fetchFromGitHub {
    owner = "Reledia";
    repo = "glow.yazi";
    rev = "536185a4e60ac0adc11d238881e78678fdf084ff";
    hash = "sha256-NcMbYjek99XgWFlebU+8jv338Vk1hm5+oW5gwH+3ZbI=";
  };
in
{
  programs.yazi = {
    enable = true;
    # disabled by default. Provides "ya" which allows for auto cding
    enableFishIntegration = true;
    keymap.manager.prepend_keymap = [
      {
        on = [ "e" ];
        run = "open";
      }
      {
        on = [ "<Enter>" ];
        run = "plugin --sync smart-enter";
        desc = "Enter the child directory, or open the file";
      }
      {
        on = [ "T" ];
        run = "plugin --sync max-preview";
        desc = "Maximize preview";
      }
      {
        on = [ "<C-n>" ];
        # there is also ripdrag but it didn't seem to work
        run = ''
          shell '${lib.getExe pkgs.xdragon} -x -i -T "$1"' --confirm
        '';
        desc = "Drag & Drop";
      }
      {
        on = [ "y" ];
        run = [
          "yank"
          ''
            shell --confirm 'for path in "$@"; do echo "file://$path"; done | wl-copy -t text/uri-list'
          ''
        ];
      }
      {
        on = [ "<C-d>" ];
        run = [ "seek 5" ];
      }
      {
        on = [ "<C-u>" ];
        run = [ "seek -5" ];
      }
    ];
    settings = lib.mkOptionDefault {
      manager = {
        ratio = [
          1
          3
          4
        ];
        show_hidden = true;
        sort_by = "modified";
        sort_reverse = true;
        sort_dir_first = true;
        show_symlink = true;
      };
      plugin = {
        prepend_previewers = [
          {
            name = "*.md";
            run = "glow";
          }
        ];
      };
    };
    # theme = builtins.fromTOML (builtins.readFile rose-pine);
  };
  xdg.configFile =
    let
      mkYaziPlugin' = dir: "yazi/plugins/" + dir;
      mkYaziPlugin = name: source: { ${mkYaziPlugin' name}.source = source; };
      mkYaziFlavor' = dir: "yazi/flavors/" + dir;
      plugins-sources = {
        "glow.yazi" = glow-plugin;
      };
      plugins = lib.mapAttrsToList (name: value: mkYaziPlugin name value) plugins-sources;
    in
    lib.fold (el: c: el // c) {
      ${mkYaziPlugin' "smart-enter.yazi/init.lua"}.source =
        builtins.toFile "init.lua" # lua
          ''
            return {
            	entry = function()
            		local h = cx.active.current.hovered
            		ya.manager_emit(h and h.cha.is_dir and "enter" or "open", { hovered = true })
            	end,
              }
          '';

      ${mkYaziPlugin' "max-preview.yazi/init.lua"}.source =
        builtins.toFile "init.lua" # lua
          ''
            local function entry(st)
              if st.old then
                Manager.layout, st.old = st.old, nil
              else
                st.old = Manager.layout
                Manager.layout = function(self, area)
                  self.area = area

                  return ui.Layout()
                    :direction(ui.Layout.HORIZONTAL)
                    :constraints({
                      ui.Constraint.Percentage(0),
                      ui.Constraint.Percentage(0),
                      ui.Constraint.Percentage(100),
                    })
                    :split(area)
                end
              end
              ya.app_emit("resize", {})
            end

            return { entry = entry }
          '';
    } plugins;
}
