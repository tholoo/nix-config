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
      configDir = "/home/tholo/.config/syncthing/";
      overrideDevices = true;
      overrideFolders = true;
      settings = {
        devices = {
          "phone" = {
            id = "DOBH5DH-W5QCXLB-VRJXL3Z-TQEQDHZ-CX6IAN3-DRZIBOK-BWZ4TKQ-YSGMVQT";
            autoAcceptFolders = true;
          };
          # "granite" = {
          #   id = "SBXNUAE-4ERWI4B-BK3VDHY-XS6LWWQ-MY55EDT-HXUH7NN-U2Q5DQC-PKOWOQA";
          #   autoAcceptFolders = true;
          # };
          "elderwood" = {
            id = "A74CQ4A-GXIY4EQ-FJ2GZYW-CSD2XRN-HIZOAGT-ESWR36I-2Q4RSF5-7YS2GQ3";
            autoAcceptFolders = true;
          };
          "glacier" = {
            id = "X6UUE6Z-VHMMJR4-5JB6V3O-FJR3H55-MNN4IBJ-W7E52EX-33HUBH2-DU4BBQP";
            autoAcceptFolders = true;
          };
        };
        folders = {
          "syncs" = {
            id = "this-is-syncs";
            path = "/home/tholo/syncs";
            devices = [
              "phone"
              # "granite"
              "elderwood"
              "glacier"
            ];
          };
        };
        gui = {
          user = "tholo";
        };
      };
    };
  };
}
