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
      enable =
        let
          tagsList = if attrs ? tags then attrs.tags else [ ];
          isInIncludes = listContainsList config.mine.tags.include tagsList;
          isInExcludes = listContainsList config.mine.tags.exclude tagsList;
        in
        mkOption {
          default = isInIncludes && !isInExcludes;
          type = types.bool;
        };
    };
}
