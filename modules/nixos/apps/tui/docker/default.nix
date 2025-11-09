{
  pkgs,
  config,
  lib,
  ...
}:
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
        extraPackages = [ pkgs.docker-buildx ];
        daemon.settings = {
          registry-mirrors = [ "https://registry.docker.ir" ];
          log-driver = "json-file";
          log-opts = {
            "max-size" = "100m";
            "max-file" = "3";
          };
        };
      };
      libvirtd.enable = true;
    };
  };
}
