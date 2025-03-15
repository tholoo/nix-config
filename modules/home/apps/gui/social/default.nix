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
  name = "social";
in
{
  options.mine.${name} = mkEnable config { tags = [ "gui" ]; };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      telegram-desktop
      ayugram-desktop
      # since 64gram and telegram-desktop share the same bin name:
      # (pkgs.writeShellScriptBin "64gram" "exec -a $0 ${lib.getExe _64gram} $@")
    ];

    xdg.dataFile."share/AyuGramDesktop/tdata/ayu_settings.json".source = ./ayu_settings.json;
    xdg.dataFile."share/AyuGramDesktop/tdata/shortcuts-custom.json".source = ./telegram_shortcuts.json;
  };
}
