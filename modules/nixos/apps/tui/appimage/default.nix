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
  name = "appimage";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "emulation"
    ];
  };

  config = mkIf cfg.enable {
    boot.binfmt = {
      # run .appimage directly
      registrations.appimage = {
        wrapInterpreterInShell = false;
        interpreter = "${lib.getExe pkgs.appimage-run}";
        recognitionType = "magic";
        offset = 0;
        mask = "\\xff\\xff\\xff\\xff\\x00\\x00\\x00\\x00\\xff\\xff\\xff";
        magicOrExtension = "\\x7fELF....AI\\x02";
      };
    };
  };
}
