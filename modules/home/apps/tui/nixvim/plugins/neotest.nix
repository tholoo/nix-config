{ pkgs, lib, ... }:
{
  plugins.neotest = {
    enable = true;
    adapters = {
      python = {
        enable = true;
        package = pkgs.vimPlugins.neotest-python;
      };
      golang.enable = true;
    };
    settings = {
      status = {
        virtual_text = true;
      };
      quickfix = {
        open = # lua
          ''
            function()
              require("trouble").open({ mode = "quickfix", focus = false })
            end
          '';
      };
    };
  };

  keymaps = lib.mkAfter [
    {
      key = "<leader>tT";
      action.__raw = # lua
        ''function() require("neotest").run.run(vim.fn.expand("%")) end'';
      mode = [ "n" ];
      options = {
        silent = true;
        noremap = true;
        desc = "Run File";
      };
    }
    {
      key = "<leader>tA";
      action.__raw = # lua
        ''function() require("neotest").run.run(vim.uv.cwd()) end'';
      mode = [ "n" ];
      options = {
        silent = true;
        noremap = true;
        desc = "Run All Test Files";
      };
    }
    {
      key = "<leader>tt";
      action.__raw = # lua
        ''function() require("neotest").run.run() end'';
      mode = [ "n" ];
      options = {
        silent = true;
        noremap = true;
        desc = "Run Nearest";
      };
    }
    {
      key = "<leader>tl";
      action.__raw = # lua
        ''function() require("neotest").run.run_last() end'';
      mode = [ "n" ];
      options = {
        silent = true;
        noremap = true;
        desc = "Run Last";
      };
    }
    {
      key = "<leader>ts";
      action.__raw = # lua
        ''function() require("neotest").summary.toggle() end'';
      mode = [ "n" ];
      options = {
        silent = true;
        noremap = true;
        desc = "Toggle Summary";
      };
    }
    {
      key = "<leader>to";
      action.__raw = # lua
        ''function() require("neotest").output.open({ enter = true, auto_close = true }) end'';
      mode = [ "n" ];
      options = {
        silent = true;
        noremap = true;
        desc = "Show Output";
      };
    }
    {
      key = "<leader>tO";
      action.__raw = # lua
        ''function() require("neotest").output_panel.toggle() end'';
      mode = [ "n" ];
      options = {
        silent = true;
        noremap = true;
        desc = "Toggle Output Panel";
      };
    }
    {
      key = "<leader>tS";
      action.__raw = # lua
        ''function() require("neotest").run.stop() end'';
      mode = [ "n" ];
      options = {
        silent = true;
        noremap = true;
        desc = "Stop";
      };
    }
    {
      key = "<leader>tw";
      action.__raw = # lua
        ''function() require("neotest").watch.toggle(vim.fn.expand("%")) end'';
      mode = [ "n" ];
      options = {
        silent = true;
        noremap = true;
        desc = "Toggle Watch";
      };
    }
  ];
}
