{ ... }:
{
  plugins.leap.enable = true;
  extraConfigLua = builtins.readFile ./leap.lua;
}
