{ pkgs, lib, ... }:
{
  programs.yazi = {
    enable = true;
    # disabled by default. Provides "ya" which allows for auto cding
    enableFishIntegration = true;
    # keymap = lib.mkOptionDefault {
      # manager.keymap = lib.mkOptionDefault [
        # { exec = "open"; on = [ "e" ]; }
      # ];
    # };
    settings = lib.mkOptionDefault {
      manager = {
        ratio = [1 3 4];
        show_hidden = true;
        sort_by = "modified";
        sort_reverse = true;
        sort_dir_first = true;
        show_symlink = true;
      };
    };
  };
}
