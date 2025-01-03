{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkOption types;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "fonts";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "gui-text"
    ];

    minimal = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to install minimal amount of fonts";
    };
  };

  config = mkIf cfg.enable {
    fonts.fontconfig = {
      enable = true;
      defaultFonts = {
        serif = [
          "Liberation Serif"
          "Vazirmatn"
        ];
        sansSerif = [
          "Ubuntu"
          "Vazirmatn"
        ];
        monospace = [
          "Ubuntu Mono"
          "Vazir Code"
        ];
      };
    };
    home.packages =
      with pkgs;
      [
        ubuntu_font_family
        liberation_ttf
        vazir-fonts # persian font
        vazir-code-font # persian font
        noto-fonts
        # symbola
        codespell
        hack-font
      ]
      ++ (with pkgs.nerd-fonts; [
        fira-code
        fira-mono
        jetbrains-mono
        overpass
        cascadia-code
        symbols-only
      ]);
  };
}
