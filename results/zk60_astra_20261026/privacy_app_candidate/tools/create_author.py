#!/usr/bin/env python3
"""Provision or rotate an author key locally; write the key to a private file."""
import argparse
import json
import os
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from proven_media import config
from proven_media.auth import AuthorAuth, handle


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("author")
    p.add_argument("--operator", action="store_true")
    p.add_argument("--rotate", action="store_true", help="Replace the existing key and revoke all its sessions.")
    args = p.parse_args()
    name = handle(args.author)
    root = config.PRIVATE_DIR.resolve()
    if root == config.REPO or config.REPO in root.parents:
        p.error("credentials must be outside the repository")
    auth = AuthorAuth(root / "auth.sqlite3")
    dest = root / (name[1:] + "-access-" + __import__('secrets').token_hex(6) + ".json")
    fd = os.open(dest, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    try:
        with os.fdopen(fd, "w") as f:
            key = auth.provision(name, operator=args.operator, rotate=args.rotate)
            json.dump({"author": name, "access_key": key}, f)
            f.write("\n")
    except Exception:
        dest.unlink(missing_ok=True)
        raise
    print(f"Credential written to {dest}; share it privately with its author.")


if __name__ == "__main__":
    main()
