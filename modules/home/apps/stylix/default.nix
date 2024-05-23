{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "stylix";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "gui"
      "theme"
    ];
  };

  config = mkIf cfg.enable {
    # colorScheme = inputs.nix-colors.colorSchemes.onedark;
    # stylix = {
    #   image = ../resources/wallpapers/wallhaven-fields-858z32.png;
    #   polarity = "dark";
    #
    #   fonts = with pkgs; rec {
    #     monospace = {
    #       name = "Fira Code";
    #       package = fira-code;
    #     };
    #     sansSerif = {
    #       name = "Cantarell";
    #       package = cantarell-fonts;
    #     };
    #     serif = sansSerif;
    #   };
    #
    #   cursor = {
    #     package = pkgs.qogir-icon-theme;
    #     name = "Qogir";
    #   };
    #
    #   targets = {
    #     waybar.enableLeftBackColors = true;
    #     waybar.enableRightBackColors = true;
    #   };
    # };
  };
}
