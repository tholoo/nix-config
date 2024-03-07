{ lib, ... }: {
  programs.waybar = {
    enable = false;
    # systemd.enable = true;
    # settings = { options = { position = "bottom"; }; };
    # settings = { "sway/workspaces" = { position = "bottom"; }; };
  };
}
