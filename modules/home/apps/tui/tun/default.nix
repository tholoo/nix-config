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
  name = "tun";

  tun-script = pkgs.writeShellScriptBin "tun" (
    builtins.replaceStrings
      [ "need tun2socks" "nohup tun2socks" ]
      [
        "need ${lib.getExe pkgs.tun2socks}"
        "nohup ${lib.getExe pkgs.tun2socks}"
      ]
      (builtins.readFile ./tun.sh)
  );
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "proxy"
      "vpn"
    ];
  };

  config = mkIf cfg.enable {
    home.packages = [ tun-script ];
  };
}
