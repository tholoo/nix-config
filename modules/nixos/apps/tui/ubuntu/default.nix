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
  name = "ubuntu";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "vm"
    ];
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ debootstrap ];
    systemd.nspawn."ubuntu" = {
      execConfig = {
        Boot = true;
        PrivateUsers = false;
      };

      filesConfig = {
        Bind = [ "/data:/data" ];
      };

      networkConfig = {
        VirtualEthernet = false;
      };
    };
  };
}
