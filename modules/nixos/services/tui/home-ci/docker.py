#!/usr/bin/python3
"""Pass runner proxy environment to containerized BuildKit, without logging it."""

import csv
import io
import os
import sys


def arguments(argv, environ):
    if argv[:2] != ["buildx", "create"]:
        return argv
    driver = "docker-container"
    supplied = set()
    for index, value in enumerate(argv):
        if value == "--driver" and index + 1 < len(argv):
            driver = argv[index + 1]
        elif value.startswith("--driver="):
            driver = value.split("=", 1)[1]
        if value.startswith("--driver-opt="):
            supplied.update(
                part.split("=", 1)[0]
                for part in next(csv.reader([value.split("=", 1)[1]]))
            )
        elif value == "--driver-opt" and index + 1 < len(argv):
            supplied.update(
                part.split("=", 1)[0] for part in next(csv.reader([argv[index + 1]]))
            )
    if driver != "docker-container":
        return argv
    extra = []
    for lower in ["http_proxy", "https_proxy", "no_proxy"]:
        if any(f"env.{name}" in supplied for name in [lower, lower.upper()]):
            continue
        value = environ.get(lower, environ.get(lower.upper(), ""))
        if value:
            # Buildx parses driver options as CSV. Quote the complete item, so
            # comma-separated no_proxy lists stay one option.
            for name in [lower, lower.upper()]:
                if f"env.{name}" not in supplied:
                    option = f"env.{name}={value}"
                    encoded = io.StringIO()
                    csv.writer(encoded, lineterminator="").writerow([option])
                    extra.extend(["--driver-opt", encoded.getvalue()])
    # Insert before any positional endpoint or '--' separator.
    return argv[:2] + extra + argv[2:]


if __name__ == "__main__":
    os.execv(
        "/usr/bin/docker", ["/usr/bin/docker", *arguments(sys.argv[1:], os.environ)]
    )
