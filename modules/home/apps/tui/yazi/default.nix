{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "yazi";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "cli-tools"
    ];
  };

  config = mkIf cfg.enable (
    let
      # TODO: somehow patch glow in init.lua with lib.getExe pkgs.glow
      glow-plugin = pkgs.fetchFromGitHub {
        owner = "Reledia";
        repo = "glow.yazi";
        rev = "5ce76dc92ddd0dcef36e76c0986919fda3db3cf5";
        hash = "sha256-UljcrXXO5DZbufRfavBkiNV3IGUNct31RxCujRzC9D4=";
      };
    in
    {
      programs.yazi = {
        enable = true;
        shellWrapperName = "f";
        keymap.mgr.prepend_keymap = [
          {
            on = [ "e" ];
            run = "open";
          }
          {
            on = [ "<Enter>" ];
            run = "plugin smart-enter";
            desc = "Enter the child directory, or open the file";
          }
          {
            on = [ "T" ];
            run = "plugin max-preview";
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
          mgr = {
            ratio = [
              1
              3
              4
            ];
            show_hidden = true;
            sort_by = "mtime";
            sort_reverse = true;
            sort_dir_first = true;
            show_symlink = true;
            linemode = "size";
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
          ${mkYaziPlugin' "smart-enter.yazi/main.lua"}.source =
            builtins.toFile "init.lua" # lua
              ''
                --- @sync entry
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
                --- @sync entry
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
  );
}
