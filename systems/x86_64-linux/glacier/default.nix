{
  config,
  inputs,
  lib,
  ...
}:
{
  imports = [ ./hardware-configuration.nix ];
  mine = {
    host = {
      name = "glacier";
      location = "Asia/Tehran";
    };

    tags.exclude = [ "server" ];

    gui.enable = true;
    tui.enable = true;

    grub.enable = true;
    systemd-boot.enable = false;
  };

  age.secrets.tholo-authorized-key = {
    file = inputs.self + /secrets/ssh/asus-public-key.age;
    path = "/run/agenix/authorized-keys/tholo";
    mode = "0444";
  };

  # srvos' desktop profile force-locks this list, so include the agenix path
  # explicitly while retaining its hardened system key location.
  services.openssh.authorizedKeysFiles = lib.mkOverride 40 [
    "/run/agenix/authorized-keys/%u"
    "/etc/ssh/authorized_keys.d/%u"
  ];

  services.resolved = {
    enable = true;

    settings.Resolve = {
      ResolveUnicastSingleLabel = true;
    };
  };

  systemd.services.nix-daemon.environment = {
    http_proxy = "http://127.0.0.1:10808";
    https_proxy = "http://127.0.0.1:10808";
    HTTP_PROXY = "http://127.0.0.1:10808";
    HTTPS_PROXY = "http://127.0.0.1:10808";
    ALL_PROXY = "http://127.0.0.1:10808";
    all_proxy = "http://127.0.0.1:10808";
  };

  security.sudo.extraConfig = ''
    Defaults env_keep += "http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY no_proxy NO_PROXY"
  '';

  # Disable speaker buzzing sound
  boot.extraModprobeConfig = ''
    snd_hda_intel power_save=0
  '';
}
