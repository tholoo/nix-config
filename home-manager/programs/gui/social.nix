{ pkgs, ... }:
{
  home.packages = with pkgs; [
    telegram-desktop
    # since 64gram and telegram-desktop share the same bin name:
    (pkgs.writeShellScriptBin "64gram" "exec -a $0 ${lib.getExe _64gram} $@")
  ];
}
