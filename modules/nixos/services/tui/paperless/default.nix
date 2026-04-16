{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "paperless";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "personal"
      "document"
      "server"
    ];
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 28981 ];

    services.paperless = {
      enable = true;
      address = "0.0.0.0";
      settings = {
        PAPERLESS_OCR_LANGUAGE = "eng+fas";
        PAPERLESS_CONSUMER_IGNORE_PATTERN = [
          ".DS_STORE/*"
          "desktop.ini"
        ];
      };
    };
  };
}
