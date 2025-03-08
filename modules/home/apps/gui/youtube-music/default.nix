{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "youtube-music";

  mkMutableSymlink =
    path:
    config.lib.file.mkOutOfStoreSymlink (
      "/home/${config.mine.user.name}/nix-config"
      + lib.removePrefix (toString inputs.self) (toString path)
    );
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
      "media"
      "music"
    ];
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ youtube-music ];
    xdg.configFile."YouTube Music/config.json".source = mkMutableSymlink ./config.json;
  };
}
