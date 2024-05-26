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
    fonts.fontconfig.enable = true;
    home.packages =
      with pkgs;
      [
        ubuntu_font_family
        vazir-fonts # persian font
        vazir-code-font # persian font
        noto-fonts
        # symbola
        codespell
        noto-fonts
      ]
      ++ (
        if cfg.minimal then
          [
            (nerdfonts.override {
              fonts = [
                "FiraCode"
                "FiraMono"
                "JetBrainsMono"
                "Overpass"
                "CascadiaCode"
              ];
            })
          ]
        else
          [ nerdfonts ]
      );
  };
}
