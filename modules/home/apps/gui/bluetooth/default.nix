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
  name = "bluetooth";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "gui"
    ];
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      (pkgs.writeShellScriptBin "blue" "exec -a $0 ${lib.getExe overskride} $@")
    ];
  };
}
