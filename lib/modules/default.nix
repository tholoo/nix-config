{ lib, inputs }:
with lib;
rec {
  listContainsList = checkContains: fold (el: c: c || builtins.elem el checkContains) false;

  mkEnable =
    config: attrs:
    attrs
    // {
      tags = mkOption {
        default = attrs.tags;
        type = with types; (listOf str);
      };
      enable = mkOption {
        default = listContainsList config.mine.tags.include (if attrs ? tags then attrs.tags else [ ]);
        type = types.bool;
      };
    };
}
