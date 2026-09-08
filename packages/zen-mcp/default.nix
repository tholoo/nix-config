{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:
buildNpmPackage {
  pname = "zen-mcp";
  version = "1.2.3";

  src = fetchFromGitHub {
    owner = "sh6drack";
    repo = "zen-mcp";
    rev = "76aa1e7140d6ae2b9400fd6d95eb8ee666facfd7";
    hash = "sha256-TppTNWrU19uL+ATQqXJIZNb8E51rlj1Hdl+FMiu0qGg=";
  };

  npmDepsHash = "sha256-LPz9uX+y5IiJXxxERgMKL1UpJc5WN1/WfQnS+ZF+yQ0=";
  dontNpmBuild = true;

  meta = {
    description = "MCP server for an existing Zen Browser session over WebDriver BiDi";
    homepage = "https://github.com/sh6drack/zen-mcp";
    license = lib.licenses.mit;
    mainProgram = "zen-mcp";
    platforms = lib.platforms.linux;
  };
}
