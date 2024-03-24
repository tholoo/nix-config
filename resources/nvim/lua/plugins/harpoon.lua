return {
  "ThePrimeagen/harpoon",
  branch = "harpoon2",
  config = function(_, opts)
    require("telescope").setup(opts)
    require("telescope").load_extension("undo")
    local harpoon = require("harpoon")
    harpoon:setup({
      settings = {
        save_on_toggle = true,
        sync_on_ui_close = true,
      },
    })

    -- basic telescope configuration
    local conf = require("telescope.config").values
    local function toggle_telescope(harpoon_files)
      local file_paths = {}
      for _, item in ipairs(harpoon_files.items) do
        table.insert(file_paths, item.value)
      end

      require("telescope.pickers")
        .new({}, {
          prompt_title = "Harpoon",
          finder = require("telescope.finders").new_table({
            results = file_paths,
          }),
          previewer = conf.file_previewer({}),
          sorter = conf.generic_sorter({}),
        })
        :find()
    end

    -- keymaps
    vim.keymap.set("n", "<leader>fh", function()
      toggle_telescope(harpoon:list())
    end, { desc = "find Harpoon" })

    vim.keymap.set("n", "<leader><C-h>", function()
      harpoon.ui:toggle_quick_menu(harpoon:list())
    end)

    vim.keymap.set("n", "<leader>H", function()
      harpoon:list():append()
    end, { desc = "Add to Harpoon list" })

    vim.keymap.set("n", "<leader>h", function()
      harpoon:list():select(1)
    end, { desc = "First Harpoon" })

    vim.keymap.set("n", "<leader>j", function()
      harpoon:list():select(2)
    end, { desc = "First Harpoon" })

    vim.keymap.set("n", "<leader>k", function()
      harpoon:list():select(3)
    end, { desc = "Second Harpoon" })

    vim.keymap.set("n", "<leader>l", function()
      harpoon:list():select(4)
    end, { desc = "Third Harpoon" })

    vim.keymap.set("n", "<leader>;", function()
      harpoon:list():select(5)
    end, { desc = "Fourth Harpoon" })

    -- Toggle previous & next buffers stored within Harpoon list
    vim.keymap.set("n", "<leader><C-k>", function()
      harpoon:list():prev()
    end, { desc = "Previous Harpoon" })

    vim.keymap.set("n", "<leader><C-j>", function()
      harpoon:list():next()
    end, { desc = "Next Harpoon" })
  end,
}
