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
      # envFile.text = ''
      # '';
      configFile.text = builtins.readFile ./config.nu;
      shellAliases = {
        e = "env $env.EDITOR";
        f = "${lib.getExe pkgs.yazi}";
        lg = lib.getExe pkgs.lazygit;
        ld = lib.getExe pkgs.lazydocker;
        # mysync = "${lib.getExe pkgs.rsync} --progress --partial --human-readable --archive --verbose --exclude-from='${./rsync-excludes.txt}'";
        fetch = lib.getExe pkgs.fastfetch;
        cat = "${lib.getExe pkgs.bat} -n";
      };
    };
  };
}
