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

  direct-script-for = commandName:
    pkgs.writeShellScriptBin commandName ''
    set -euo pipefail

    if [[ "$#" -eq 0 ]]; then
      echo "Usage: ${commandName} <command> [argument ...]" >&2
      exit 2
    fi

    unit="tun-direct-$(${pkgs.coreutils}/bin/date +%s%N)-$$"

    exec ${pkgs.systemd}/bin/systemd-run \
      --user \
      --scope \
      --slice=tun-direct.slice \
      --unit="$unit" \
      --same-dir \
      --quiet \
      "$@"
  '';

  direct-script = direct-script-for "direct";
  dg-script = direct-script-for "dg";
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
    home.packages = [
      tun-script
      direct-script
      dg-script
    ];
  };
}
