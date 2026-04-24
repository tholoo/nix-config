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
    home.packages = with pkgs; [
      autossh
    ];

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks =
        let
          cat = lib.getExe' pkgs.coreutils "cat";
          sed = lib.getExe pkgs.gnused;
          nc = lib.getExe pkgs.netcat;
        in
        with config.age.secrets;
        {
          "*" = {
            addKeysToAgent = "yes";
            serverAliveInterval = 15;
            serverAliveCountMax = 5;
          };
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
          parsa-hetzner-germany = {
            user = "poweruser";
            checkHostIP = false;
            proxyCommand = "bash -c '${nc} $(${cat} ${ip-parsa-hetzner-germany.path}) %p'";
          };
          ahmad-hetzner-germany = {
            user = "root";
            checkHostIP = false;
            proxyCommand = "bash -c '${nc} $(${cat} ${ip-ahmad-hetzner-germany.path}) %p'";
          };
          parsa-iranserver-tehran = {
            user = "root";
            checkHostIP = false;
            proxyCommand = "bash -c '${nc} $(${cat} ${ip-parsa-iranserver-tehran.path}) %p'";
          };
          parsa-asiatech-tehran = {
            user = "root";
            checkHostIP = false;
            proxyCommand = "bash -c '${nc} $(${cat} ${ip-parsa-asiatech-tehran.path}) %p'";
          };
          flint = {
            user = "root";
            checkHostIP = false;
            proxyCommand = "bash -c '${nc} $(${cat} ${ip-flint.path}) %p'";
          };
          parsa-asiatech-tehran2 = {
            user = "root";
            checkHostIP = false;
            proxyCommand = "bash -c '${nc} $(${cat} ${ip-parsa-asiatech-tehran2.path}) %p'";
          };
          mohammad-do = {
            user = "root";
            checkHostIP = false;
            proxyCommand = "bash -c '${nc} $(${cat} ${ip-mohammad-do.path}) %p'";
          };
        };
    };
    services.ssh-agent.enable = true;
  };
}
