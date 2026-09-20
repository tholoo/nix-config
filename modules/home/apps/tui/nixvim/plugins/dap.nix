{ pkgs, ... }:
let
  codelldb = pkgs.vscode-extensions.vadimcn.vscode-lldb;
  codelldbAdapter = "${codelldb}/share/vscode/extensions/vadimcn.vscode-lldb/adapter/codelldb";
in
{
  plugins = {
    dap = {
      enable = true;
      adapters.servers.codelldb = {
        port = "\${port}";
        executable = {
          command = codelldbAdapter;
          args = [
            "--port"
            "\${port}"
          ];
        };
      };
      configurations.rust = [
        {
          name = "Debug Cargo tests";
          type = "codelldb";
          request = "launch";
          program.__raw = ''
            function()
              local root = vim.fs.root(0, "Cargo.toml")
              assert(root, "No Cargo.toml found for the current buffer")

              vim.notify("Building Rust test executable…", vim.log.levels.INFO)
              local result = vim.system(
                { "cargo", "test", "--no-run", "--message-format=json" },
                { cwd = root, text = true }
              ):wait()
              if result.code ~= 0 then
                local output = result.stderr ~= "" and result.stderr or result.stdout
                error("cargo test --no-run failed:\n" .. (output or "no output"))
              end

              local artifacts = {}
              local seen = {}
              for line in (result.stdout or ""):gmatch("[^\r\n]+") do
                local ok, message = pcall(vim.json.decode, line)
                if ok
                  and message.reason == "compiler-artifact"
                  and message.executable
                  and message.profile
                  and message.profile.test
                  and not seen[message.executable]
                then
                  seen[message.executable] = true
                  table.insert(artifacts, {
                    label = message.target and message.target.name or vim.fs.basename(message.executable),
                    path = message.executable,
                  })
                end
              end

              assert(#artifacts > 0, "Cargo produced no test executable")
              if #artifacts == 1 then
                return artifacts[1].path
              end

              table.sort(artifacts, function(left, right)
                return left.label < right.label
              end)
              local choices = { "Select Cargo test executable:" }
              for index, artifact in ipairs(artifacts) do
                table.insert(choices, string.format("%d. %s", index, artifact.label))
              end
              local selected = vim.fn.inputlist(choices)
              assert(selected > 0 and artifacts[selected], "Debugging cancelled")
              return artifacts[selected].path
            end
          '';
          cwd.__raw = ''
            function()
              return assert(vim.fs.root(0, "Cargo.toml"), "No Cargo.toml found for the current buffer")
            end
          '';
          args.__raw = ''
            function()
              local filter = vim.fn.input("Test filter (blank runs all): ")
              if filter == "" then
                return { "--nocapture" }
              end
              return { filter, "--nocapture" }
            end
          '';
          env.RUST_BACKTRACE = "1";
          sourceLanguages = [ "rust" ];
          stopOnEntry = false;
        }
        {
          name = "Launch Rust executable";
          type = "codelldb";
          request = "launch";
          program.__raw = ''
            function()
              return vim.fn.input("Executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
            end
          '';
          cwd = "\${workspaceFolder}";
          sourceLanguages = [ "rust" ];
          stopOnEntry = false;
        }
      ];
      signs = {
        dapBreakpoint.text = "●";
        dapBreakpointCondition.text = "◆";
        dapLogPoint.text = "◆";
        dapStopped.text = "▶";
        dapBreakpointRejected.text = "○";
      };
    };
    dap-python = {
      enable = true;
      testRunner = "unittest";
    };
    dap-ui.enable = true;
    dap-virtual-text = {
      enable = true;
      settings = {
        clear_on_continue = true;
        commented = true;
      };
    };
  };

  plugins.which-key.settings.spec = [
    {
      __unkeyed-1 = "<leader>d";
      group = "debug";
    }
  ];

  extraConfigLua = ''
    local dap = require("dap")
    local dapui = require("dapui")

    dap.listeners.after.event_initialized["editor_dap_ui"] = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated["editor_dap_ui"] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited["editor_dap_ui"] = function()
      dapui.close()
    end

    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
    end

    map("n", "<leader>db", dap.toggle_breakpoint, "Toggle breakpoint")
    map("n", "<leader>dB", function()
      dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
    end, "Conditional breakpoint")
    map("n", "<leader>dc", dap.continue, "Continue or start debugger")
    map("n", "<leader>dn", dap.step_over, "Step over")
    map("n", "<leader>di", dap.step_into, "Step into")
    map("n", "<leader>do", dap.step_out, "Step out")
    map("n", "<leader>dl", dap.run_last, "Run last debug session")
    map("n", "<leader>dq", dap.terminate, "Terminate debugger")
    map("n", "<leader>dr", dap.repl.toggle, "Toggle debug REPL")
    map("n", "<leader>du", dapui.toggle, "Toggle debug UI")
    map({ "n", "x" }, "<leader>de", dapui.eval, "Evaluate expression")
    map("n", "<leader>dt", function()
      if vim.bo.filetype == "python" then
        require("dap-python").test_method()
      elseif vim.bo.filetype == "rust" then
        dap.run(dap.configurations.rust[1])
      else
        vim.notify("Debug test is configured for Python and Rust", vim.log.levels.WARN)
      end
    end, "Debug test")
  '';
}
