"""Precompile extension sources without bundling or moving import.meta paths."""

import json
from pathlib import Path
import re
import subprocess
import sys

PACKAGES = [
    "pi-mcp-adapter", "pi-web-access", "pi-subagents", "@aliou/pi-processes",
    "@narumitw/pi-goal",
]
RELATIVE_TS = re.compile(r'''(["'])(\.{1,2}/[^"'\n]+)\.ts\1''')


def compile_extensions(root, esbuild):
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


if __name__ == "__main__":
    compile_extensions(*sys.argv[1:])
