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
  name = "theme";

  themes = {
    catppuccin-mocha = {
      scheme = "catppuccin-mocha";
      polarity = "dark";
    };
    catppuccin-latte = {
      scheme = "catppuccin-latte";
      polarity = "light";
    };
    gruvbox-dark = {
      scheme = "gruvbox-dark-hard";
      polarity = "dark";
    };
    tokyo-night = {
      scheme = "tokyo-night-dark";
      polarity = "dark";
    };
    dracula = {
      scheme = "dracula";
      polarity = "dark";
    };
    nord = {
      scheme = "nord";
      polarity = "dark";
    };
    rose-pine = {
      scheme = "rose-pine";
      polarity = "dark";
    };
    rose-pine-dawn = {
      scheme = "rose-pine-dawn";
      polarity = "light";
    };
  };
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "theme"
    ];
  };

  config = mkIf cfg.enable {
    stylix = {
      enable = true;
      image = "${inputs.self}/resources/wallpapers/wallhaven-fields-858z32.png";
      base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
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

      targets.plymouth.enable = false;
    };

    specialisation = builtins.mapAttrs (_: theme: {
      configuration = {
        stylix = {
          base16Scheme = lib.mkForce "${pkgs.base16-schemes}/share/themes/${theme.scheme}.yaml";
          polarity = lib.mkForce theme.polarity;
        };
      };
    }) themes;
  };
}
