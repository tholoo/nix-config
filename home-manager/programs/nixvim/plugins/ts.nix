{ pkgs, ... }: {
  ts-autotag.enable = true;
  ts-context-commentstring.enable = true;
  typescript-tools = {
    enable = true;
    settings = {
      tsserverPath =
        "${pkgs.nodePackages.typescript}/lib/node_modules/typescript/lib/tsserver.js";
    };
  };
}
