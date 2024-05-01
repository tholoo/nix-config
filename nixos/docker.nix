{ ... }:
{
  virtualisation = {
    docker = {
      enable = true;
      daemon.settings = {
        registry-mirrors = [ "https://registry.docker.ir" ];
      };
    };
    libvirtd.enable = true;
  };
}
