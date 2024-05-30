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
  name = "nushell";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "shell"
    ];
  };

  config = mkIf cfg.enable {
    programs.nushell = {
      enable = true;
      package = pkgs.nushellFull;
      # envFile.text = ''
      # '';
      configFile.text = ''
        $env.config = {
           show_banner: false,
           edit_mode: vi,
         }
      '';
      shellAliases = {
        # e = "$env.EDITOR";
        f = "${lib.getExe pkgs.yazi}";
        lg = lib.getExe pkgs.lazygit;
        # mysync = "${lib.getExe pkgs.rsync} --progress --partial --human-readable --archive --verbose --exclude-from='${./rsync-excludes.txt}'";
        fetch = lib.getExe pkgs.fastfetch;
        cat = "${lib.getExe pkgs.bat} -n";
      };
    };
  };
}
