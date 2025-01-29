{ ... }:
{
  plugins = {
    debugprint.enable = true;
    dap = {
      enable = true;
    };
    dap-python = {
      enable = true;
      customConfigurations = [
        {
          type = "python";
          request = "launch";
          name = "DAP Django";
          program = "vim.loop.cwd() .. '/manage.py'";
          args = [
            "runserver"
            "--noreload"
          ];
          justMyCode = true;
          django = true;
          console = "integratedTerminal";
        }
      ];
    };
    dap-ui.enable = true;
    dap-virtual-text.enable = true;
  };

  extraConfigLua = # lua
    ''
      local dap = require("dap")
      local dapui = require("dapui")
      dapui.setup(opts)
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open({})
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close({})
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close({})
      end
    '';

  keymaps = [
    {
      key = "<leader>dB";
      action.__raw = ''function() require("dap").set_breakpoint(vim.fn.input('Breakpoint condition: ')) end'';
      mode = "n";
      options = {
        silent = true;
        noremap = true;
        desc = "Breakpoint Condition";
      };
    }
    {
      key = "<leader>db";
      action.__raw = ''function() require("dap").toggle_breakpoint() end'';
      mode = "n";
      options = {
        silent = true;
        noremap = true;
        desc = "Toggle Breakpoint";
      };
    }
    {
      key = "<leader>dc";
      action.__raw = ''function() require("dap").continue() end'';
      mode = "n";
      options = {
        silent = true;
        noremap = true;
        desc = "Continue";
      };
    }
    {
      key = "<leader>da";
      action.__raw = ''function() require("dap").continue({ before = get_args }) end'';
      mode = "n";
      options = {
        silent = true;
        noremap = true;
        desc = "Run with Args";
      };
    }
    {
      key = "<leader>dC";
      action.__raw = ''function() require("dap").run_to_cursor() end'';
      mode = "n";
      options = {
        silent = true;
        noremap = true;
        desc = "Run to Cursor";
      };
    }
    {
      key = "<leader>dg";
      action.__raw = ''function() require("dap").goto_() end'';
      mode = "n";
      options = {
        silent = true;
        noremap = true;
        desc = "Go to Line (No Execute)";
      };
    }
    {
      key = "<leader>di";
      action.__raw = ''function() require("dap").step_into() end'';
      mode = "n";
      options = {
        silent = true;
        noremap = true;
        desc = "Step Into";
      };
    }
    {
      key = "<leader>dJ";
      action.__raw = ''function() require("dap").down() end'';
      mode = "n";
      options = {
        silent = true;
        noremap = true;
        desc = "Down";
      };
    }
    {
      key = "<leader>dK";
      action.__raw = ''function() require("dap").up() end'';
      mode = "n";
      options = {
        silent = true;
        noremap = true;
        desc = "Up";
      };
    }
    {
      key = "<leader>dl";
      action.__raw = ''function() require("dap").run_last() end'';
      mode = "n";
      options = {
        silent = true;
        noremap = true;
        desc = "Run Last";
      };
    }
    {
      key = "<leader>dk";
      action.__raw = ''function() require("dap").step_out() end'';
      mode = "n";
      options = {
        silent = true;
        noremap = true;
        desc = "Step Out";
      };
    }
    {
      key = "<leader>dj";
      action.__raw = ''function() require("dap").step_over() end'';
      mode = "n";
      options = {
        silent = true;
        noremap = true;
        desc = "Step Over";
      };
    }
    {
      key = "<leader>dp";
      action.__raw = ''function() require("dap").pause() end'';
      mode = "n";
      options = {
        silent = true;
        noremap = true;
        desc = "Pause";
      };
    }
    # {
    #   key = "<leader>dr";
    #   action.__raw = ''function() require("dap").repl.toggle() end'';
    #   mode = "n";
    #   options = {
    #     silent = true;
    #     noremap = true;
    #     desc = "Toggle REPL";
    #   };
    # }
    {
      key = "<leader>ds";
      action.__raw = ''function() require("dap").session() end'';
      mode = "n";
      options = {
        silent = true;
        noremap = true;
        desc = "Session";
      };
    }
    {
      key = "<leader>dt";
      action.__raw = ''function() require("dap").terminate() end'';
      mode = "n";
      options = {
        silent = true;
        noremap = true;
        desc = "Terminate";
      };
    }
    {
      key = "<leader>dw";
      action.__raw = ''function() require("dap.ui.widgets").hover() end'';
      mode = "n";
      options = {
        silent = true;
        noremap = true;
        desc = "Widgets";
      };
    }
  ];
}
