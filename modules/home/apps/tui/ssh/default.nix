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
  name = "ssh";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "tui"
      "cli-tools"
    ];
  };

  config = mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      addKeysToAgent = "yes";
      serverAliveInterval = 60;
      serverAliveCountMax = 60;
      matchBlocks =
        let
          cat = lib.getExe' pkgs.coreutils "cat";
          sed = lib.getExe pkgs.gnused;
          nc = lib.getExe pkgs.netcat;
        in
        with config.age.secrets;
        {
          github = {
            hostname = "github.com";
            user = "git";
          };
          gitlab = {
            hostname = "gitlab.com";
            user = "git";
          };
          granite = {
            user = "tholo";
            checkHostIP = false;
            # get the ip from secrets
            proxyCommand = "bash -c '${nc} $(${cat} ${ip-granite.path}) %p'";
          };
          ahm = {
            user = "root";
            checkHostIP = false;
            # get the ip from secrets. first line is ip and the second is the port
            proxyCommand = "bash -c \"${nc} $(${sed} -n '1p' ${ip-ahm.path}) $(${sed} -n '2p' ${ip-ahm.path})\"";
          };
        };
    };
    services.ssh-agent.enable = true;
  };
}
