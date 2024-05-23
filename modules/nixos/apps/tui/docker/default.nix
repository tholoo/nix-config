{ config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.mine) mkEnable;
  cfg = config.mine.${name};
  name = "docker";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "cli-tools"
      "deploy"
    ];
  };

  config = mkIf cfg.enable {
    virtualisation = {
      docker = {
        enable = true;
        daemon.settings = {
          registry-mirrors = [ "https://registry.docker.ir" ];
        };
      };
      libvirtd.enable = true;
    };
  };
}
