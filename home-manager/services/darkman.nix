{ ... }:
{
  # auto dark mode
  services.darkman = {
    enable = true;
    settings = {
      usegeoclue = true;
    };
  };
}
