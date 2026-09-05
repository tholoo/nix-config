# Working in this repository

This is a public NixOS and Home Manager flake using Snowfall Lib and the
`mine` namespace. Keep changes declarative in the relevant module; use the
existing `lib.mine.mkEnable` pattern. Its tags match ANY included tag, with
excluded tags taking precedence. Explicit enable overrides belong in host/home
configuration files.

Inspect the relevant `systems/`, `homes/`, and module files for current settings.
Format changed Nix files with the flake formatter. Evaluate affected host/home
outputs and build changed packages; report evaluation/build separately from
activation. New files must be included when validating a Git-backed flake.

For desktop-control or agent-browser changes, read
`docs/agent-tools.md` and run the package's Python tests. Desktop interactions
should use `agent-desktop` with an explicit window address and a fresh screenshot.

Keep checked-in instructions and examples generic. Discover private paths,
service URLs, network topology and account details locally only when needed;
keep those discoveries, browser profiles, screenshots and credentials outside
the repository and the Nix store. Refer to secrets through existing agenix
mechanisms. Describe validation with synthetic examples and aggregate results.
