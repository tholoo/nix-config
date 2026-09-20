{ testPlugins }:
{ ... }:
{
  # Neotest propagates Lua modules. Use the nightly editor's package set
  # rather than mixing its interpreter with Nixvim's separate Nixpkgs pin.
  # Extend the plugin set so adapter dependencies use the same instances too.
  nixpkgs.overlays = [
    (_final: prev: {
      vimPlugins = prev.vimPlugins.extend (
        _plugins: _old: {
          inherit (testPlugins) neotest nvim-nio;
        }
      );
    })
  ];

  plugins.neotest = {
    enable = true;
    # Runners and project dependencies come from the project's dev shell.
    adapters = {
      python.enable = true;
      golang.enable = true;
      rust.enable = true;
      jest.enable = true;
      vitest.enable = true;
    };
    settings = {
      # Keep results available without opening windows after every run.
      output.open_on_run = false;
      quickfix.open = false;
    };
  };

  plugins.which-key.settings.spec = [
    {
      __unkeyed-1 = "<leader>t";
      group = "tests";
    }
  ];

  extraConfigLua = ''
    local neotest = require("neotest")
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("editor_neotest_output", { clear = true }),
      pattern = "neotest-output",
      callback = function(event)
        vim.keymap.set({ "n", "t" }, "<Esc>", function()
          vim.api.nvim_win_close(0, true)
        end, { buffer = event.buf, silent = true, desc = "Close test output" })
      end,
    })
    local map = function(lhs, rhs, desc)
      vim.keymap.set("n", lhs, rhs, { silent = true, desc = desc })
    end
    map("<leader>tt", neotest.run.run, "Run nearest test")
    map("<leader>tf", function()
      neotest.run.run(vim.fn.expand("%:p"))
    end, "Run tests in file")
    map("<leader>ta", function()
      neotest.run.run(vim.fn.getcwd())
    end, "Run tests in working directory")
    map("<leader>tw", function()
      neotest.watch.toggle(vim.fn.expand("%:p"))
    end, "Toggle watching tests in file")
    map("<leader>tl", neotest.run.run_last, "Run last test")
    map("<leader>ts", neotest.run.stop, "Stop nearest test")
    map("<leader>tS", neotest.summary.toggle, "Toggle test summary")
    map("<leader>to", function()
      neotest.output.open({ enter = true, auto_close = true })
    end, "Show test output")
    map("<leader>tO", neotest.output_panel.toggle, "Toggle test output panel")
    map("<leader>tn", function()
      neotest.jump.next({ status = "failed" })
    end, "Next failed test")
    map("<leader>tp", function()
      neotest.jump.prev({ status = "failed" })
    end, "Previous failed test")
  '';
}
