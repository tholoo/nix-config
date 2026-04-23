{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
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
      "theme"
    ];
  };

  config = mkIf cfg.enable {
    stylix = {
      enable = true;
      image = "${inputs.self}/resources/wallpapers/wallhaven-fields-858z32.png";
      base16Scheme = "${pkgs.base16-schemes}/share/themes/ayu-dark.yaml";
      polarity = "dark";

      fonts = {
        monospace = {
          name = "JetBrainsMono Nerd Font";
          package = pkgs.nerd-fonts.jetbrains-mono;
        };
        sansSerif = {
          name = "Cantarell";
          package = pkgs.cantarell-fonts;
        };
        serif = {
          name = "Cantarell";
          package = pkgs.cantarell-fonts;
        };
        sizes = {
          terminal = 13;
          applications = 11;
        };
      };

      cursor = {
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Ice";
        size = 24;
      };

      targets = {
        hyprpanel.enable = true;
        zen-browser.profileNames = [ "default" ];
        floorp.profileNames = [ "Default" ];
      };
    };
  };
}
