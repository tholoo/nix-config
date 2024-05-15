{ pkgs, ... }:
{
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
}
