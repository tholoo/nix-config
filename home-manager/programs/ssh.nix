{ ... }: {
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
    };
  };
  services.ssh-agent.enable = true;
}
