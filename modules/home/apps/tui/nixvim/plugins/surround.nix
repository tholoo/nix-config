{ pkgs, ... }:
{
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
      -- https://github.com/kylechui/nvim-surround/blob/main/lua/nvim-surround/config.lua
      surrounds = {
        ["c"] = {
            add = { "```", "```" },
            find = function()
                return require("nvim-surround").get_selection({ motion = "ac" })
            end,
            delete = "^(```)().-(```)()$",
        },
        ["C"] = {
            add = { "```python", "```" },
            find = function()
                return require("nvim-surround").get_selection({ motion = "aC" })
            end,
            delete = "^(```python)().-(```)()$",
        },
        ['"'] = {
            add = { '"', '"' },
            find = function()
                return require("nvim-surround").get_selection({ motion = 'a"' })
            end,
            delete = "^(.)().-(.)()$",
        },
      },
      aliases = {
        ["q"] =  '"',
      }
    })
  '';
}
