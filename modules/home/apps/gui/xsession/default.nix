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
  name = "xsession";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "i3"
    ];
  };

  config = mkIf cfg.enable {
    # xsession = {
    #   enable = true;
    #   windowManager = {
    #     i3 = {
    #       enable = true;
    #       config = {
    #         modifier = "Mod4";
    #         terminal = "${lib.getExe pkgs.wezterm}";
    #         # switch to previous workspace by pressing this workspace's key again
    #         workspaceAutoBackAndForth = true;
    #         menu = "${lib.getExe pkgs.rofi} -show drun";
    #         defaultWorkspace = "1";
    #         window = {
    #           hideEdgeBorders = "smart";
    #         };
    #       };
    #     };
    #   };
    # };
  };
}
