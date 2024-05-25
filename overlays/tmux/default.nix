{ channels, ... }:
final: prev: {
  tmux = prev.tmux.overrideAttrs (oldAttrs: {
    version = "3.4.99";
    src = final.fetchFromGitHub {
      owner = "tmux";
      repo = "tmux";
      rev = "c07e856d244d07ab2b65e72328fb9fe20747794b";
      hash = "sha256-99hdAskEByqD4fjl2wrth9QfSkPXkN7o2A9e+BOH6ug=";
    };
    patches = [ ];
  });
}
