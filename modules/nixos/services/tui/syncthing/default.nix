{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "syncthing";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "tui"
      "sync"
    ];
  };

  config = mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      user = "tholo";
      dataDir = "/home/tholo/syncs";
      overrideDevices = true;
      overrideFolders = true;
      settings = {
        devices = {
          "phone" = {
            id = "DOBH5DH-W5QCXLB-VRJXL3Z-TQEQDHZ-CX6IAN3-DRZIBOK-BWZ4TKQ-YSGMVQT";
          };
        };
        folders = {
          "tholos" = {
            path = "/home/tholo/tholos";
            devices = [ "phone" ];
          };
        };
        gui = {
          user = "tholo";
        };
      };
    };
  };
}
