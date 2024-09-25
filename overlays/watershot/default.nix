{ channels, ... }:
final: prev: {
  tmux = prev.watershot.overrideAttrs (oldAttrs: {
    src = final.fetchFromGitHub {
      owner = "Liassica";
      repo = "watershot";
      rev = "17225900e909a1d499f7534e4056cea7418a60d0";
      hash = "sha256-mnBBxFwpw4KBnioCF2RG0eHSjtgRnSDxxDuaYt+T5Uk=";
    };
  });
}
