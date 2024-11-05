{ pkgs, ... }:
{
  ts-autotag.enable = true;
  ts-context-commentstring.enable = true;
  typescript-tools = {
    enable = true;
    settings.settings = {
      tsserver_path = "${pkgs.nodePackages.typescript}/lib/node_modules/typescript/lib/tsserver.js";
      expose_as_code_action = "all";
    };
  };
}
