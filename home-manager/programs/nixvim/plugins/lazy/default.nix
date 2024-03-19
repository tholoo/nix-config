{ pkgs, lib, getNixFiles, getPlugin, ... }: {
  lazy = {
    # this currently disables all other plugins

    # enable = true;
    # plugins = [{
    #   pkg = pkgs.vimPlugins.nvim-surround;
    #   enabled = true;
    #   event = "VeryLazy";
    #   main = "nvim-surround";
    #   opts = {
    #     keymaps = {
    #       normal = "s";
    #       normal_cur = "ss";
    #       visual = "s";
    #       visual_line = "gs";
    #     };
    #   };
    # }];

    # FIXME: I have no idea why this doesn't work
    # plugins = lib.fold (el: c:
    #   let plugin = getPlugin el;
    #   in if builtins.isList plugin then c ++ plugin else c ++ [ plugin ]) [ ]
    #   (lib.remove "default.nix" (getNixFiles ./.));
  };
}
