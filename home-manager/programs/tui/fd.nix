{ ... }:
{
  programs.fd = {
    enable = true;
    hidden = true;
    extraOptions = [ "--no-global-ignore-file" ];
    ignores = [
      ".DS_Store"
      ".cache/"
      ".direnv/"
      ".env/"
      ".git/"
      ".mypy_cache/"
      ".ruff_cache/"
      ".venv/"
      "__pycache__/"
      "node_modules/"
      "venv/"
    ];
  };
}
