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
  name = "fonts";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "gui-text"
    ];
  };

  config = mkIf cfg.enable {
    fonts.fontconfig.enable = true;
    home.packages = with pkgs; [
      (nerdfonts.override {
        fonts = [
          "FiraCode"
          "FiraMono"
          "JetBrainsMono"
          "Overpass"
          "CascadiaCode"
        ];
      })
      ubuntu_font_family
      vazir-fonts # persian font
      vazir-code-font # persian font
      noto-fonts
      # symbola
      codespell
    ];
  };
}
