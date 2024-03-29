{ ... }: {
  # TODO: switch to fuzzel
  programs.wofi = {
    enable = true;
    style = builtins.readFile ./style.css;
    settings = {
      allow_images = true;
      allow_markup = true;
      key_backward = "Ctrl-p";
      key_forward = "Ctrl-n";
      matching = "fuzzy";
    };
  };
}
