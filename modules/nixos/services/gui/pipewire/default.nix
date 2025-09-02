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
  name = "pipewire";
in
{
  options.mine.${name} = mkEnable config {
    tags = [
      "service"
      "gui"
      "audio"
    ];
  };

  config = mkIf cfg.enable {
    services.pipewire = {
      enable = true;
      audio.enable = true;
      extraConfig.pipewire = {
        "99-silent-bell.conf" = {
          "context.properties" = {
            "module.x11.bell" = false;
          };
        };
      };
      wireplumber = {
        enable = true;
        # Higher quality for bluetooth
        configPackages = [
          (pkgs.writeTextDir "share/wireplumber/bluetooth.lua.d/51-bluez-config.lua" ''
            bluez_monitor.properties = {
              ["bluez5.enable-sbc-xq"] = true,
              ["bluez5.enable-msbc"] = true,
              ["bluez5.enable-hw-volume"] = true,
            }
          '')
        ];
      };
      pulse.enable = true;
      # jack.enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
    };
    boot = {
      kernelModules = [
        "btusb"
        "bluetooth"

        "snd-seq"
        "snd-rawmidi"
        "v4l2loopback"
      ];
      extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
      extraModprobeConfig = ''
        options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
      '';
    };
    environment.etc."modprobe.d/bluetooth.conf".text = ''
      options btusb enable_autosuspend=0
    '';
  };
}
