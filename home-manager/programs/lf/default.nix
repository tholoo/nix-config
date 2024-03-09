{ pkgs, ... }: {
  xdg.configFile."lf/icons".source = ./icons;
  programs.lf = {
    enable = true;
    settings = {
      number = true;
      preview = true;
      hidden = true;
      drawbox = true;
      icons = true;
      ignorecase = true;
      previewer = ''${pkgs.pistol}/bin/pistol "$file"'';
    };
  };
}
