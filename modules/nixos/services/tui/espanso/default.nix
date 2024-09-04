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
  name = "espanso";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "tui"
    ];
  };

  config = mkIf cfg.enable {
    services.espanso = {
      enable = false;
      wayland = true;
    };
    # security.wrappers.espanso = {
    #   source = lib.getExe pkgs.espanso-wayland;
    #   capabilities = "cap_dac_override=eip";
    #   owner = "root";
    # };
  };
}
