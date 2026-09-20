"""Precompile extensions, bundling the UI with lazy Shiki imports."""

import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

PACKAGES = [
    "pi-mcp-adapter", "pi-web-access", "pi-subagents", "@aliou/pi-processes",
    "@narumitw/pi-goal", "pi-vim",
    "@juicesharp/rpiv-ask-user-question", "@narumitw/pi-worktree",
    "@narumitw/pi-stamp",
]
RELATIVE_TS = re.compile(r'''(["'])(\.{1,2}/[^"'\n]+)\.ts\1''')


def bundle_web_html_dependencies(package, esbuild):
    # Pi's standalone loader handles static imports, but native lazy imports
    # cannot resolve bare packages (including their transitive dependencies).
    # Bundle only the HTML libraries; keep extraction and shared state unbundled
    # and preserve upstream first-use loading via relative chunk imports.
    dependencies = [
        ("linkedom", "linkedom", "*", 2),
        ("@mozilla/readability", "readability", "{ Readability }", 1),
        ("turndown", "turndown", "{ default }", 1),
        ("defuddle/node", "defuddle", "{ Defuddle }", 1),
    ]
    extractor = package / "extract.js"
    source = extractor.read_text()
    # Stable paths keep esbuild's source labels and chunk hashes reproducible.
    temporary = package / ".html-deps"
    temporary.mkdir()
    try:
        entries = []
        for specifier, name, exports, count in dependencies:
            old = f'import("{specifier}")'
            if source.count(old) != count:
                raise RuntimeError(f"Unexpected pi-web-access lazy imports: {specifier}")
            source = source.replace(old, f'import("./precompiled/html/{name}.js")')
            entry = temporary / f"{name}.js"
            entry.write_text(f'export {exports} from "{specifier}";\n')
            entries.append(str(entry))
        subprocess.run([
            esbuild, *entries, "--bundle", "--splitting", "--format=esm",
            "--platform=node", "--target=es2022",
            f"--outdir={package / 'precompiled/html'}", "--log-level=warning",
        ], check=True)
    finally:
        shutil.rmtree(temporary)
    extractor.write_text(source)


def compile_extensions(root, esbuild):
    # Resolve Shiki's dynamic package imports at build time: Pi's standalone
    # loader cannot resolve those bare imports at runtime. Splitting keeps
    # languages/themes lazy, while SDK imports still use Pi's shared runtime.
    ui = Path(root) / "pi-claude-code-ui"
    subprocess.run([
        esbuild, str(ui / "extensions/index.ts"),
        str(ui / "extensions/spinner.ts"), "--bundle", "--splitting",
        "--format=esm", "--platform=node", "--target=es2022",
        "--external:@earendil-works/pi-coding-agent",
        "--external:@earendil-works/pi-tui",
        f"--outdir={ui / 'precompiled'}", "--log-level=warning",
    ], check=True)
    manifest = ui / "package.json"
    data = json.loads(manifest.read_text())
    data["pi"]["extensions"] = ["./precompiled/index.js", "./precompiled/spinner.js"]
    manifest.write_text(json.dumps(data, indent=2) + "\n")

    # The permission gate uses extensionless imports and #src aliases. Bundle
    # its implementation and public service separately; their session registry
    # is deliberately shared via Symbol.for(), not via module identity.
    gate = Path(root) / "@gotgenes/pi-permission-system"
    manifest = gate / "package.json"
    data = json.loads(manifest.read_text())
    # Package imports are exact targets, unlike relative TS imports. Make the
    # upstream extensionless alias explicit for esbuild's package resolution.
    data["imports"]["#src/*"] = "./src/*.ts"
    manifest.write_text(json.dumps(data, indent=2) + "\n")
    subprocess.run([
        esbuild, str(gate / "src/index.ts"), str(gate / "src/service.ts"),
        "--bundle", "--format=esm", "--platform=node", "--target=es2022",
        "--external:@earendil-works/*", "--external:web-tree-sitter",
        "--external:tree-sitter-bash", "--external:zod",
        f"--outdir={gate / 'precompiled'}", "--log-level=warning",
    ], check=True)
    manifest = gate / "package.json"
    data = json.loads(manifest.read_text())
    data["pi"]["extensions"] = ["./precompiled/index.js"]
    data["exports"]["."]["default"] = "./precompiled/service.js"
    manifest.write_text(json.dumps(data, indent=2) + "\n")
    # auto-review ships compiled ESM already and resolves the public service
    # above at runtime, keeping Pi's provider/SDK aliases external.

    for name in PACKAGES:
        package = Path(root) / name
        sources = [p for p in package.rglob("*.ts") if not p.name.endswith(".d.ts")]
        subprocess.run([
            esbuild, *map(str, sources), "--format=esm", "--platform=node",
            "--target=es2022", f"--outbase={package}", f"--outdir={package}",
            "--log-level=warning",
        ], check=True)
        for source in sources:
            output = source.with_suffix(".js")
            def replace(match):
                # Preserve external paths; only rewrite a target compiled here.
                target = output.parent / (match[2] + ".js")
                return f"{match[1]}{match[2]}.js{match[1]}" if target.is_file() else match[0]
            output.write_text(RELATIVE_TS.sub(replace, output.read_text()))
        manifest = package / "package.json"
        data = json.loads(manifest.read_text())
        def rewrite(value):
            if isinstance(value, str) and value.endswith(".ts") and (package / value).with_suffix(".js").is_file():
                return value[:-3] + ".js"
            if isinstance(value, list):
                return [rewrite(x) for x in value]
            if isinstance(value, dict):
                return {k: rewrite(v) for k, v in value.items()}
            return value
        for key in ("pi", "exports", "main"):
            if key in data:
                data[key] = rewrite(data[key])
        manifest.write_text(json.dumps(data, indent=2) + "\n")
        if name == "pi-web-access":
            bundle_web_html_dependencies(package, esbuild)


if __name__ == "__main__":
    compile_extensions(*sys.argv[1:])
