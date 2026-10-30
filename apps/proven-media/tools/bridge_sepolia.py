#!/usr/bin/env python3
"""Execute or reconcile the two authorized testnet bridge deposits."""
import argparse
import fcntl
import json
from pathlib import Path
import sys

APP = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(APP))
from proven_media.base_sepolia import read_throwaway_key
from proven_media.publisher import PublishError
from proven_media.sepolia_bridge import SepoliaBridge, TestnetRPC, L1_CHAIN, L2_CHAIN


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('stage', choices=['canary', 'bulk'])
    parser.add_argument('--private-dir', type=Path, default=APP / '.testnet-private')
    args = parser.parse_args()
    directory = args.private_dir
    if directory.is_symlink() or directory.stat().st_mode & 0o077:
        raise PublishError('bridge private directory must be a real0700 directory')
    with (directory / 'bridge.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        account = read_throwaway_key(directory / 'throwaway.sepolia-key.json')
        bridge = SepoliaBridge(TestnetRPC('https://eth-sepolia.api.onfinality.io/public', L1_CHAIN),
                               TestnetRPC('https://base-sepolia.api.onfinality.io/public', L2_CHAIN), directory)
        print(json.dumps(bridge.run(args.stage, account)))


if __name__ == '__main__':
    try:
        main()
    except PublishError as error:
        print(json.dumps({'status': 'refused', 'reason': str(error)}))
        raise SystemExit(1)
