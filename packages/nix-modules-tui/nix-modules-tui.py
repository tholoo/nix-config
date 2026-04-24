#!/usr/bin/env python3
"""TUI for exploring NixOS/home-manager module states across hosts."""

import re
import sys
from pathlib import Path
from dataclasses import dataclass, field

from textual.app import App, ComposeResult
from textual.widgets import DataTable, Header, Footer, Input, Static, Select
from textual.containers import Vertical, Horizontal
from textual.binding import Binding
from rich.text import Text


@dataclass
class Module:
    name: str
    tags: list[str]
    path: str
    layer: str  # "nixos" or "home"
    category: str  # e.g. "apps/tui", "services/gui"
    enabled: bool = True
    reason: str = ""
    explicit: bool = False  # True if explicitly overridden


@dataclass
class HostConfig:
    name: str
    include_tags: list[str] = field(default_factory=list)
    exclude_tags: list[str] = field(default_factory=list)
    explicit_overrides: dict[str, bool] = field(default_factory=dict)


def find_config_root() -> Path:
    """Find the nix-config root directory."""
    # Check if passed as argument
    if len(sys.argv) > 1 and sys.argv[1] == "--config-dir":
        return Path(sys.argv[2])
    # Try common locations
    candidates = [
        Path.cwd(),
        Path.home() / "nix-config",
        Path("/etc/nixos"),
    ]
    for p in candidates:
        if (p / "flake.nix").exists() and (p / "modules").exists():
            return p
    print("Error: Could not find nix-config root. Use --config-dir <path>", file=sys.stderr)
    sys.exit(1)


def parse_nix_list(text: str) -> list[str]:
    """Extract items from a Nix list literal like [ "a" "b" "c" ]."""
    return re.findall(r'"([^"]*)"', text)


def parse_modules(config_dir: Path) -> list[Module]:
    """Scan all module directories and extract module metadata."""
    modules = []
    module_base = config_dir / "modules"

    for layer in ["nixos", "home"]:
        layer_dir = module_base / layer
        if not layer_dir.exists():
            continue

        for nix_file in layer_dir.rglob("default.nix"):
            content = nix_file.read_text()

            # Skip files without mkEnable (suites, tags, base configs)
            if "mkEnable" not in content:
                continue

            # Extract module name
            name_match = re.search(r'name\s*=\s*"([^"]+)"', content)
            if not name_match:
                continue
            name = name_match.group(1)

            # Extract tags
            tags_match = re.search(r'tags\s*=\s*\[([^\]]*)\]', content)
            tags = parse_nix_list(tags_match.group(1)) if tags_match else []

            # Determine category from path
            rel = nix_file.parent.relative_to(layer_dir)
            parts = list(rel.parts)
            # Category is like "apps/tui", "services/gui", "grub", etc.
            if len(parts) >= 2:
                category = f"{parts[0]}/{parts[1]}"
            elif len(parts) == 1:
                category = parts[0]
            else:
                category = ""

            modules.append(Module(
                name=name,
                tags=tags,
                path=str(nix_file.relative_to(config_dir)),
                layer=layer,
                category=category,
            ))

    return sorted(modules, key=lambda m: (m.layer, m.category, m.name))


def parse_host_config(config_dir: Path, host: str, layer: str) -> HostConfig:
    """Parse a host/home config to extract tag settings and explicit overrides."""
    hc = HostConfig(name=host)

    if layer == "nixos":
        config_file = config_dir / "systems" / "x86_64-linux" / host / "default.nix"
    else:
        # Find home config for this host
        homes_dir = config_dir / "homes" / "x86_64-linux"
        candidates = list(homes_dir.glob(f"*@{host}"))
        if not candidates:
            return hc
        config_file = candidates[0] / "default.nix"

    if not config_file.exists():
        return hc

    content = config_file.read_text()

    # Extract suites enabled (mine.tui.enable = true, mine.gui.enable = true)
    for suite in ["tui", "gui"]:
        if re.search(rf'\b{suite}\.enable\s*=\s*true\b', content):
            hc.include_tags.append(suite)

    # Extract exclude tags
    exclude_match = re.search(r'tags\.exclude\s*=\s*\[([^\]]*)\]', content)
    if exclude_match:
        hc.exclude_tags = parse_nix_list(exclude_match.group(1))

    # Extract explicit overrides in various Nix syntax forms:
    # 1. mine.moduleName.enable = true/false;
    # 2. moduleName.enable = true/false;  (inside mine = { ... })
    # 3. moduleName = { enable = true/false; ... }; (inside mine = { ... })
    skip_names = {"tui", "gui", "tags", "host", "user"}

    # Pattern 1: dotted path form
    for m in re.finditer(r'(?:mine\.)(\S+?)\.enable\s*=\s*(true|false)', content):
        mod_name = m.group(1)
        value = m.group(2) == "true"
        if mod_name not in skip_names:
            hc.explicit_overrides[mod_name] = value

    # Pattern 2: inside mine = { ... } block — simple dotted
    for m in re.finditer(r'^\s+([\w-]+)\.enable\s*=\s*(true|false)\s*;', content, re.MULTILINE):
        mod_name = m.group(1)
        value = m.group(2) == "true"
        if mod_name not in skip_names:
            hc.explicit_overrides[mod_name] = value

    # Pattern 3: block form like  moduleName = { enable = false; ... };
    for m in re.finditer(r'^\s+([\w-]+)\s*=\s*\{[^}]*\benable\s*=\s*(true|false)\b', content, re.MULTILINE):
        mod_name = m.group(1)
        value = m.group(2) == "true"
        if mod_name not in skip_names:
            hc.explicit_overrides[mod_name] = value

    return hc


def compute_states(modules: list[Module], nixos_config: HostConfig, home_config: HostConfig) -> list[Module]:
    """Compute enable/disable state for each module with reasons."""
    for mod in modules:
        config = nixos_config if mod.layer == "nixos" else home_config

        # Check explicit override first
        if mod.name in config.explicit_overrides:
            mod.enabled = config.explicit_overrides[mod.name]
            mod.explicit = True
            mod.reason = f"explicitly {'enabled' if mod.enabled else 'disabled'} in host config"
            continue

        if not mod.tags:
            mod.enabled = False
            mod.reason = "no tags defined"
            continue

        # Check tag-based enable logic
        matching_include = [t for t in mod.tags if t in config.include_tags]
        matching_exclude = [t for t in mod.tags if t in config.exclude_tags]

        is_included = len(matching_include) > 0
        is_excluded = len(matching_exclude) > 0

        if is_included and not is_excluded:
            mod.enabled = True
            mod.reason = f"included by tag: {', '.join(matching_include)}"
        elif is_included and is_excluded:
            mod.enabled = False
            mod.reason = f"included by [{', '.join(matching_include)}] but excluded by [{', '.join(matching_exclude)}]"
        elif is_excluded:
            mod.enabled = False
            mod.reason = f"excluded by tag: {', '.join(matching_exclude)}"
        else:
            mod.enabled = False
            tags_str = ', '.join(mod.tags)
            mod.reason = f"tags [{tags_str}] not in included tags [{', '.join(config.include_tags)}]"

    return modules


def discover_hosts(config_dir: Path) -> list[str]:
    """Find all available hosts."""
    systems_dir = config_dir / "systems" / "x86_64-linux"
    if not systems_dir.exists():
        return []
    return sorted([d.name for d in systems_dir.iterdir() if d.is_dir()])


class ModuleTUI(App):
    CSS = """
    #controls {
        height: 3;
        dock: top;
        padding: 0 1;
    }
    #filter-input {
        width: 1fr;
    }
    #host-select {
        width: 20;
    }
    #filter-select {
        width: 22;
    }
    #layer-select {
        width: 16;
    }
    #stats {
        height: 1;
        dock: bottom;
        padding: 0 1;
        background: $surface;
        color: $text-muted;
    }
    DataTable {
        height: 1fr;
    }
    """

    BINDINGS = [
        Binding("q", "quit", "Quit"),
        Binding("e", "filter_enabled", "Enabled"),
        Binding("d", "filter_disabled", "Disabled"),
        Binding("a", "filter_all", "All"),
        Binding("n", "next_host", "Next Host"),
        Binding("/", "focus_search", "Search"),
        Binding("escape", "clear_search", "Clear"),
    ]

    def __init__(self, config_dir: Path, initial_host: str | None = None):
        super().__init__()
        self.config_dir = config_dir
        self.hosts = discover_hosts(config_dir)
        self.current_host = initial_host or (self.hosts[0] if self.hosts else "")
        self.all_modules = parse_modules(config_dir)
        self.filter_text = ""
        self.filter_status = "all"  # "all", "enabled", "disabled"
        self.filter_layer = "all"  # "all", "nixos", "home"

    def compose(self) -> ComposeResult:
        yield Header(show_clock=False)
        with Horizontal(id="controls"):
            yield Select(
                [(h, h) for h in self.hosts],
                value=self.current_host,
                id="host-select",
                allow_blank=False,
            )
            yield Select(
                [("All", "all"), ("Enabled", "enabled"), ("Disabled", "disabled")],
                value="all",
                id="filter-select",
                allow_blank=False,
            )
            yield Select(
                [("All Layers", "all"), ("NixOS", "nixos"), ("Home", "home")],
                value="all",
                id="layer-select",
                allow_blank=False,
            )
            yield Input(placeholder="Search modules...", id="filter-input")
        yield DataTable(id="table")
        yield Static("", id="stats")
        yield Footer()

    def on_mount(self) -> None:
        table = self.query_one(DataTable)
        table.cursor_type = "row"
        table.add_columns("Status", "Module", "Layer", "Category", "Tags", "Reason")
        self.refresh_table()

    def compute_modules(self) -> list[Module]:
        """Recompute module states for current host."""
        import copy
        modules = copy.deepcopy(self.all_modules)
        nixos_config = parse_host_config(self.config_dir, self.current_host, "nixos")
        home_config = parse_host_config(self.config_dir, self.current_host, "home")
        return compute_states(modules, nixos_config, home_config)

    def refresh_table(self) -> None:
        table = self.query_one(DataTable)
        table.clear()

        modules = self.compute_modules()
        search = self.filter_text.lower()

        shown = 0
        enabled_count = 0
        disabled_count = 0

        for mod in modules:
            if mod.enabled:
                enabled_count += 1
            else:
                disabled_count += 1

            # Apply status filter
            if self.filter_status == "enabled" and not mod.enabled:
                continue
            if self.filter_status == "disabled" and mod.enabled:
                continue

            # Apply layer filter
            if self.filter_layer != "all" and mod.layer != self.filter_layer:
                continue

            # Apply text search
            if search:
                searchable = f"{mod.name} {mod.layer} {mod.category} {' '.join(mod.tags)} {mod.reason}".lower()
                if search not in searchable:
                    continue

            status = Text("ON ", style="bold green") if mod.enabled else Text("OFF", style="bold red")
            name_style = "bold" if mod.explicit else ""
            name_text = Text(mod.name, style=name_style)
            layer_text = Text(mod.layer, style="cyan" if mod.layer == "nixos" else "magenta")
            tags_text = Text(", ".join(mod.tags), style="dim")

            table.add_row(status, name_text, layer_text, mod.category, tags_text, mod.reason)
            shown += 1

        self.title = f"Nix Modules - {self.current_host}"
        stats = self.query_one("#stats", Static)
        stats.update(
            f" {self.current_host}: {enabled_count} enabled, {disabled_count} disabled, "
            f"{len(modules)} total | showing {shown}"
        )

    def on_select_changed(self, event: Select.Changed) -> None:
        if event.select.id == "host-select":
            self.current_host = event.value
        elif event.select.id == "filter-select":
            self.filter_status = event.value
        elif event.select.id == "layer-select":
            self.filter_layer = event.value
        self.refresh_table()

    def on_input_changed(self, event: Input.Changed) -> None:
        if event.input.id == "filter-input":
            self.filter_text = event.value
            self.refresh_table()

    def action_filter_enabled(self) -> None:
        self.filter_status = "enabled"
        self.query_one("#filter-select", Select).value = "enabled"
        self.refresh_table()

    def action_filter_disabled(self) -> None:
        self.filter_status = "disabled"
        self.query_one("#filter-select", Select).value = "disabled"
        self.refresh_table()

    def action_filter_all(self) -> None:
        self.filter_status = "all"
        self.query_one("#filter-select", Select).value = "all"
        self.refresh_table()

    def action_next_host(self) -> None:
        if not self.hosts:
            return
        idx = self.hosts.index(self.current_host)
        self.current_host = self.hosts[(idx + 1) % len(self.hosts)]
        self.query_one("#host-select", Select).value = self.current_host
        self.refresh_table()

    def action_focus_search(self) -> None:
        self.query_one("#filter-input", Input).focus()

    def action_clear_search(self) -> None:
        inp = self.query_one("#filter-input", Input)
        inp.value = ""
        self.filter_text = ""
        self.refresh_table()
        self.query_one(DataTable).focus()


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Explore NixOS module states")
    parser.add_argument("--config-dir", type=Path, help="Path to nix-config root")
    parser.add_argument("host", nargs="?", help="Initial host to display")
    args = parser.parse_args()

    config_dir = args.config_dir or find_config_root()
    app = ModuleTUI(config_dir, initial_host=args.host)
    app.run()


if __name__ == "__main__":
    main()
