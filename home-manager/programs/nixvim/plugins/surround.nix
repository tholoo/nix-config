{ pkgs, ... }: {
  plugins = { };
  extraPlugins = with pkgs.vimPlugins; [ nvim-surround ];
  extraConfigLua = ''
    require("nvim-surround").setup({
      keymaps = {
        normal = "s",
        normal_cur = "ss",
        visual = "s",
        visual_line = "gs",
      },
    })
  '';
}
