{
  disko.devices.disk = {
    nixos = {
      type = "disk";
      device = "/dev/sda2";
      content = {
        type = "filesystem";
        format = "ext4";
        mountpoint = "/";
      };
    };
    efi = {
      type = "disk";
      device = "/dev/sda1";
      content = {
        type = "filesystem";
        format = "vfat";
        mountpoint = "/boot";
      };
    };
  };
}
