{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "qbittorrent";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "gui"
      "download"
      "torrent"
    ];
  };

  config = mkIf cfg.enable {
    services.${name} = {
      enable = true;
      extraArgs = [ "--confirm-legal-notice" ];
    };
  };
}
