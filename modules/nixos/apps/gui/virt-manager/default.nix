{ }
# {
#   inputs,
#   pkgs,
#   config,
#   lib,
#   ...
# }:
# let
#   inherit (lib) mkIf;
#   inherit (lib.mine) mkEnable;
#   cfg = config.mine.${name};
#   name = "virt-manager";
# in
# {
#   options.mine.${name} = mkEnable config {
#     tags = [
#       "gui"
#       "emulation"
#     ];
#   };

#   config = mkIf cfg.enable {
#     #   programs.dconf.enable = true;

#     environment.systemPackages = [
#       inputs.NixVirt.packages.x86_64-linux.default
#     ];

#     networking = {
#       bridges = {
#         "br0" = {
#           interfaces = [
#             "wlp3s0"
#             "virbr0"
#             "eth0"
#           ];
#         };
#       };
#       interfaces = {
#         eth0.useDHCP = true;
#         br0.useDHCP = true;
#         wlp3s0.useDHCP = true;
#       };
#       # interfaces.br0 = {
#       #   ipv4.addresses = [
#       #     {
#       #       address = "192.168.1.122";
#       #       prefixLength = 24;
#       #     }
#       #   ];
#       # };
#     };

#     virtualisation.libvirt = {
#       enable = true;
#       swtpm.enable = true;
#       connections = {
#         "qemu:///system" = {
#           # networks = [
#           #     {
#           #       definition = inputs.NixVirt.lib.network.writeXML (
#           #         inputs.NixVirt.lib.network.templates.bridge {
#           #           uuid = "70b08691-28dc-4b47-90a1-45bbeac9ab5a";
#           #           subnet_byte = 71;
#           #         }
#           #       );
#           #       active = true;
#           #     }
#           #   ];
#           # };
#           # "qemu:///session" = {
#           #   {
#           #     definition = inputs.NixVirt.lib.network.writeXML {
#           #       name = "default";
#           #       uuid = "dc7f9f29-6449-4e38-b0cd-808f43c73257";
#           #       forward = {
#           #         mode = "nat";
#           #         nat = {
#           #           port = {
#           #             start = 1024;
#           #             end = 65535;
#           #           };
#           #         };
#           #       };
#           #       bridge = {
#           #         name = "virbr0";
#           #       };
#           #       mac = {
#           #         address = "52:54:00:02:77:4b";
#           #       };
#           #       ip = {
#           #         address = "192.168.74.1";
#           #         netmask = "255.255.255.0";
#           #         dhcp = {
#           #           range = {
#           #             start = "192.168.74.2";
#           #             end = "192.168.74.254";
#           #           };
#           #         };
#           #       };
#           #     };
#           #     active = true;
#           #   }
#           # ];
#           pools = [
#             {
#               definition = inputs.NixVirt.lib.pool.writeXML {
#                 name = "Windows11Pool";
#                 uuid = "67c1ebdb-d9d8-4755-87eb-8218cd4498c0";
#                 type = "dir";
#                 target = {
#                   path = "/home/tholo/vms";
#                 };
#               };
#               active = true;
#               volumes = [
#                 {
#                   definition = inputs.NixVirt.lib.volume.writeXML {
#                     name = "MainDisk";
#                     capacity = {
#                       count = 128;
#                       unit = "GB";
#                     };
#                     target.format.type = "qcow2";
#                   };
#                 }
#               ];
#             }
#           ];
#           domains = [
#             {
#               active = true;
#               restart = true;
#               definition = inputs.NixVirt.lib.domain.writeXML (
#                 inputs.NixVirt.lib.domain.templates.windows {
#                   name = "Win11";
#                   uuid = "7c18ca00-6b78-48e4-a8f2-2b7c47f2fdc0";
#                   memory = {
#                     count = 8;
#                     unit = "GiB";
#                   };
#                   storage_vol = {
#                     pool = "Windows11Pool";
#                     volume = "MainDisk";
#                   };
#                   install_vol = /home/tholo/vms/windows-11.iso;
#                   nvram_path = /home/tholo/vms/windows-11-nvram.ms.fd;
#                   # nvram_path = builtins.exec "cp ${pkgs.OVMFFull.fd}/FV/OVMF_VARS.ms.fd /home/tholo/vms/windows-11-nvram.ms.fd";
#                   virtio_net = true;
#                   virtio_drive = true;
#                   install_virtio = true;
#                 }
#               );
#             }
#           ];
#         };
#       };
#     };

#     #   #   users.users.gcis = {
#     #   #     isSystemUser = true;
#     #   #     group = "gcis";
#     #   #     extraGroups = [ "libvirtd" ];
#     #   #   };
#     #   #   users.groups.gcis = { };

#     #   #   programs.virt-manager.enable = true;
#     #   #   environment.systemPackages = with pkgs; [
#     #   #     virt-viewer
#     #   #     spice
#     #   #     spice-gtk
#     #   #     spice-protocol
#     #   #     win-virtio
#     #   #     win-spice

#     #   #     adwaita-icon-theme
#     #   #     glib
#     #   #   ];

#     # virtualisation = {
#     # libvirtd = {
#     # enable = true;
#     #       qemu = {
#     #         #         package = pkgs.qemu_kvm;
#     #         #         runAsRoot = true;
#     #         swtpm.enable = true;
#     #         #         ovmf = {
#     #         #           enable = true;
#     #         #           packages = [
#     #         #             (pkgs.OVMFFull.override {
#     #         #               secureBoot = true;
#     #         #               tpmSupport = true;
#     #         #             }).fd
#     #         #           ];
#     #         #         };
#     #       };
#     #     };
#     #     #     spiceUSBRedirection.enable = true;
#     #   };
#     #   #   services.spice-vdagentd.enable = true;
#   };
# }
