{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "minecraft-server";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "tui"
      "server"
      "game"
    ];
  };

  config = mkIf cfg.enable {
    # minecraft-server = {
    # enable = true;
    # openFirewall = true;
    # declarative = true;
    # eula = true;
    # serverProperties = {
    # server-port = 43000;
    # difficulty = 3;
    # gamemode = 1;
    # max-players = 5;
    # motd = "Thoohohohohoohlo";
    # };
    # };
  };
}
