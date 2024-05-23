{ lib, inputs }:
with lib;
with lib.mine;
{
  mkEnable =
    config: attrs:
    attrs
    // {
      enable = mkOption {
        default = listContainsList config.mine.includeTags (if attrs ? tags then attrs.tags else [ ]);
        type = types.bool;
      };
    };
}
