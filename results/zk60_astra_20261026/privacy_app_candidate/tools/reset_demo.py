#!/usr/bin/env python3
"""Preview, or archive and reset a finished demo. Never runs a prover or RPC."""
import argparse
import json
from pathlib import Path
import sqlite3
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from proven_media import config
from proven_media.demo_reset import ResetRefused, preview, reset


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--private-root', type=Path, default=config.PRIVATE_DIR)
    p.add_argument('--public-root', type=Path, default=config.PUBLIC_DIR)
    p.add_argument('--apply', action='store_true', help='Archive database and empty the finished feed; default is read-only preview.')
    args = p.parse_args()
    try:
        result = (reset if args.apply else preview)(args.private_root, args.public_root)
    except (ResetRefused, OSError, sqlite3.Error) as exc:
        print(json.dumps({'reset': False, 'error': str(exc)}))
        return 1
    print(json.dumps(result, indent=2))
    return 0 if result.get('ready', True) else 1


if __name__ == '__main__':
    raise SystemExit(main())
