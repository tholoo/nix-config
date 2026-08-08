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
      sshpass
    ];

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings =
        let
          cat = lib.getExe' pkgs.coreutils "cat";
          sed = lib.getExe pkgs.gnused;
          nc = lib.getExe pkgs.netcat;
        in
        with config.age.secrets;
        {
          "*" = {
            AddKeysToAgent = "yes";
            ServerAliveInterval = 15;
            ServerAliveCountMax = 5;
          };
          github = {
            HostName = "github.com";
            User = "git";
          };
          gitlab = {
            HostName = "gitlab.com";
            User = "git";
          };
          granite = {
            User = "tholo";
            CheckHostIP = false;
            # get the ip from secrets
            ProxyCommand = "bash -c '${nc} $(${cat} ${ip-granite.path}) %p'";
          };
          parsa-hetzner-germany = {
            User = "poweruser";
            CheckHostIP = false;
            ProxyCommand = "bash -c '${nc} $(${cat} ${ip-parsa-hetzner-germany.path}) %p'";
          };
          ahmad-hetzner-germany = {
            User = "root";
            CheckHostIP = false;
            ProxyCommand = "bash -c '${nc} $(${cat} ${ip-ahmad-hetzner-germany.path}) %p'";
          };
          parsa-iranserver-tehran = {
            User = "root";
            CheckHostIP = false;
            ProxyCommand = "bash -c '${nc} $(${cat} ${ip-parsa-iranserver-tehran.path}) %p'";
          };
          parsa-asiatech-tehran = {
            User = "root";
            CheckHostIP = false;
            ProxyCommand = "bash -c '${nc} $(${cat} ${ip-parsa-asiatech-tehran.path}) %p'";
          };
          flint = {
            User = "tholo";
            CheckHostIP = false;
            ProxyCommand = "bash -c '${nc} $(${cat} ${ip-flint.path}) %p'";
          };
          parsa-asiatech-tehran2 = {
            User = "root";
            CheckHostIP = false;
            ProxyCommand = "bash -c '${nc} $(${cat} ${ip-parsa-asiatech-tehran2.path}) %p'";
          };
          mohammad-do = {
            User = "root";
            CheckHostIP = false;
            ProxyCommand = "bash -c '${nc} $(${cat} ${ip-mohammad-do.path}) %p'";
          };
        };
    };
    services.ssh-agent.enable = true;
  };
}
