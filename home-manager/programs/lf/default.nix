{ pkgs, ... }: {
  xdg.configFile."lf/icons".source = ./icons;
  programs.lf = {
    enable = true;
    commands = {
      mkdir = ''
        ''${{
          printf "Directory Name: "
          read DIR
          mkdir -p $DIR
        }}
      '';
    };
    settings = {
      number = true;
      preview = true;
      hidden = true;
      drawbox = true;
      icons = true;
      ignorecase = true;
    };
    keybindings = {
      "<enter>" = "open";
      o = "mkdir";
    };
    previewer.source = pkgs.pistol + /bin/pistol;
  };
}
