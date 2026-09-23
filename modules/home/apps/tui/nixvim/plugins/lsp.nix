{ ... }:
{
  # nvim-lspconfig supplies server definitions; Neovim's native API starts them.
  plugins.lspconfig.enable = true;
  lsp.servers = {
    "*".config.capabilities.__raw = "require('blink.cmp').get_lsp_capabilities()";
    nixd.enable = true;
    lua_ls = {
      enable = true;
      config.settings.Lua = {
        runtime.version = "LuaJIT";
        diagnostics.globals = [ "vim" ];
        workspace.checkThirdParty = false;
        telemetry.enable = false;
      };
    };
    basedpyright = {
      enable = true;
      config.settings.basedpyright.analysis = {
        typeCheckingMode = "standard";
        diagnosticMode = "openFilesOnly";
      };
    };
    ruff.enable = true;
    ts_ls.enable = true;
    rust_analyzer = {
      enable = true;
      config.settings.rust-analyzer = {
        check.command = "clippy";
        cargo.buildScripts.enable = true;
        procMacro.enable = true;
      };
    };
    gopls.enable = true;
    clangd.enable = true;
    bashls.enable = true;
    jsonls.enable = true;
    yamlls.enable = true;
    taplo.enable = true;
    html.enable = true;
    cssls = {
      enable = true;
      config.on_init.__raw = ''
        function(client)
          client:notify("css/customDataChanged", {
            { vim.uri_from_fname("${./tailwind.css-data.json}") }
          })
        end
      '';
    };
    marksman.enable = true;
  };
  # fzf-lua centers after the async jump, including single-result navigation.
  lsp.keymaps = [
    {
      key = "gd";
      action.__raw = "require('fzf-lua').lsp_definitions";
      options.desc = "Go to definition";
    }
    {
      key = "gD";
      action.__raw = "require('fzf-lua').lsp_declarations";
      options.desc = "Go to declaration";
    }
    {
      key = "gy";
      action.__raw = "require('fzf-lua').lsp_typedefs";
      options.desc = "Go to type definition";
    }
    {
      key = "<leader>cr";
      lspBufAction = "rename";
      options.desc = "Rename symbol";
    }
    {
      key = "<leader>ca";
      lspBufAction = "code_action";
      mode = [
        "n"
        "x"
      ];
      options.desc = "Code action";
    }
    {
      key = "gr";
      action.__raw = "require('fzf-lua').lsp_references";
      options.desc = "References";
    }
    {
      key = "gi";
      action.__raw = "require('fzf-lua').lsp_implementations";
      options.desc = "Implementations";
    }
  ];
}
