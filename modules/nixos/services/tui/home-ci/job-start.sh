#!/bin/bash
set -eu
# Mask proxy URLs before workflow steps can echo expanded command arguments.
python3 - <<'PY'
import os
for value in sorted({os.environ.get(name, "") for name in (
    "http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY"
)} - {""}):
    escaped = value.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    print(f"::add-mask::{escaped}")
PY
