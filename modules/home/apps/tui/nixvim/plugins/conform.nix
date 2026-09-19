{ pkgs, lib, ... }:
{
  plugins.conform-nvim = {
    enable = true;
    settings = {
      format_on_save.__raw = "function(buf) if not vim.b[buf].disable_autoformat then return { timeout_ms = 500, lsp_format = 'fallback' } end end";
      formatters_by_ft = {
        nix = [ "nixfmt" ];
        lua = [ "stylua" ];
        python = [ "ruff_format" ];
        rust = [ "rustfmt" ];
        go = [ "gofmt" ];
        sh = [ "shfmt" ];
        bash = [ "shfmt" ];
        javascript = [ "prettierd" ];
        javascriptreact = [ "prettierd" ];
        typescript = [ "prettierd" ];
        typescriptreact = [ "prettierd" ];
        json = [ "prettierd" ];
        jsonc = [ "prettierd" ];
        yaml = [ "prettierd" ];
        html = [ "prettierd" ];
        css = [ "prettierd" ];
        markdown = [ "prettierd" ];
        toml = [ "taplo" ];
      };
      formatters = {
        nixfmt.command = lib.getExe pkgs.nixfmt;
        stylua.command = lib.getExe pkgs.stylua;
        ruff_format.command = lib.getExe pkgs.ruff;
        shfmt.command = lib.getExe pkgs.shfmt;
        prettierd.command = lib.getExe pkgs.prettierd;
        taplo.command = lib.getExe pkgs.taplo;
        # Rust/Go formatting follows the project's toolchain from its dev shell.
      };
    };
  };
}
