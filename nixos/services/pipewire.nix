{ pkgs, ... }:
{
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
            ["bluez5.headset-roles"] = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]"
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
}
