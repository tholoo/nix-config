{
  lib,
  vimUtils,
  fetchFromGitHub,
}:
vimUtils.buildVimPlugin {
  pname = "processing-vim";
  version = "2024-11-17";
  src = fetchFromGitHub {
    owner = "sophacles";
    repo = "vim-processing";
    rev = "91aaa18a54f8e507e48353ba87b1eb4ecd82a17c";
    hash = "sha256-xxsRxtWNwhzt158bxVzcJDs/sTDeTNt/+35vIOWXFR0=";
  };
  meta.homepage = "https://github.com/sophacles/vim-processing";
}
