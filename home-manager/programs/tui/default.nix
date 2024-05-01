{
  pkgs,
  lib,
  getNixFiles,
  ...
}:
{
  imports = getNixFiles ./.;
}
