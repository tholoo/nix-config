{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";
    serverAliveInterval = 60;
    serverAliveCountMax = 60;
    matchBlocks = {
      github = {
        hostname = "github.com";
        user = "git";
      };
      gitlab = {
        hostname = "gitlab.com";
        user = "git";
      };
      "tholo.tech" = {
        user = "tholo";
        checkHostIP = false;
        # get the ip from secrets
        proxyCommand = "${lib.getExe pkgs.netcat} $(${lib.getExe' pkgs.coreutils "cat"} ${config.age.secrets.ip-tholo-tech.path}) %p";
      };
    };
  };
  services.ssh-agent.enable = true;
}
