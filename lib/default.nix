{ lib, inputs }:
with lib;
{
  getNixFiles =
    dir:
    map (file: dir + "/${file}") (
      attrNames (
        filterAttrs (
          file: type: (type == "directory") || ((hasSuffix ".nix" file) && !(hasInfix "default" file))
        ) (builtins.readDir dir)
      )
    );
}
