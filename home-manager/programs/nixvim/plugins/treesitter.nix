{
  treesitter = {
    enable = true;

    nixvimInjections = true;

    folding = false;
    indent = true;
  };

  treesitter-refactor = {
    enable = true;
    highlightDefinitions.enable = true;
  };

  treesitter-textobjects = { enable = true; };

  hmts.enable = true;
}
