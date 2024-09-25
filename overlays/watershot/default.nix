{ channels, ... }:
final: prev: {
  tmux = prev.watershot.overrideAttrs (oldAttrs: {
    src = final.fetchFromGitHub {
      owner = "Liassica";
      repo = "watershot";
      rev = "tmp-hyprland-fix";
      hash = "sha256-/FV9WUdM8JSTX5w/JXVA7ymTJEHyovo0Fz2F1PVO/hU=";
    };
  });
}
