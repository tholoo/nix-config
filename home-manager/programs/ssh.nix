{ ... }: {
  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";
    matchBlocks = {
      "github" = {
        hostname = "github.com";
        user = "git";
      };
    };
  };
  services.ssh-agent.enable = true;
}
