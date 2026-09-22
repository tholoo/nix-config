{ mpvPackage, filePackage }:
{ lib, ... }:
let
  mediaFiles = ''require("editor.yazi-media").open(files, "${lib.getExe filePackage}", "${lib.getExe mpvPackage}")'';
in
{
  plugins.yazi = {
    enable = true;
    settings = {
      open_for_directories = true;
      floating_window_scaling_factor = 1.0;
      yazi_floating_window_border = "none";
      keymaps.open_file_in_tab = false;
      # Chooser mode bypasses Yazi's opener rules; route videos after selection.
      open_file_function = lib.mkIf (mpvPackage != null) {
        __raw = ''
          function(path)
            local files = { path }
            local editor_files = ${mediaFiles}
            if #editor_files > 0 then
              require("yazi.openers").open_file(editor_files[1])
            end
          end
        '';
      };
      hooks.yazi_opened_multiple_files = lib.mkIf (mpvPackage != null) {
        __raw = ''
          function(files)
            local editor_files = ${mediaFiles}
            if #editor_files > 0 then
              require("yazi.openers").open_multiple_files(editor_files)
            end
          end
        '';
      };
    };
  };
  extraFiles."lua/editor/yazi-media.lua".source = ./yazi-media.lua;
}
