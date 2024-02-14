{
  programs.nixvim = {
    plugins = {
      # copilot-vim = {
      #   enable = true;
      #   # proxy = "localhost:2081"
      # };
      copilot-lua = {
        enable = true;
      };
      copilot-cmp = {
        enable = true;
      };
    };
  };
}
