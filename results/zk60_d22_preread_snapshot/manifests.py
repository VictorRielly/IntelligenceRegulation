"""The two pinned Cargo manifests in the snapshot: digest vs pin, and the
joint-view gate's own CONTENT assertion (finding P36-2) run on them.

Read-only: imports `zk60_native_manifest_pins` from the joint-view worktree
with bytecode writing off and calls `assert_manifest_policy` on the snapshot's
bytes; also runs the whole `check_manifest_pins` on the snapshot root to show
what the gate itself would say today.

    python3 results/zk60_d22_preread_snapshot/manifests.py [--snapshot DIR]
"""
from __future__ import annotations

import argparse
import hashlib
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, "/home/victor/wt-zk60-jointview/scripts")
import zk60_native_manifest_pins as mp  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--snapshot", default="/tmp/claude-1000/d22-snapshot")
    a = ap.parse_args()
    for pin in mp.MANIFEST_PINS:
        raw = open(os.path.join(a.snapshot, pin.path), "rb").read()
        got = hashlib.sha256(raw).hexdigest()
        print(f"{pin.path}: snapshot {got}  pin {pin.sha256}  "
              f"{'EQUAL' if got == pin.sha256 else 'MOVED'}")
        exp = mp.EXPECTED_AFTER_INTEGRATION.get(pin.path, {})
        if exp:
            print(f"  EXPECTED_AFTER_INTEGRATION {exp['sha256']} "
                  f"{'= snapshot' if exp['sha256'] == got else '!= snapshot'}")
        try:
            r = mp.assert_manifest_policy(pin.path, raw.decode(),
                                          mp.MANIFEST_POLICY[pin.path])
            print(f"  content assertion: ACCEPTED {r}")
        except Exception as e:  # noqa: BLE001
            print(f"  content assertion: REFUSED {type(e).__name__}: {e}")
        print(f"  token 'test-observers' present: {b'test-observers' in raw}; "
              f"'resolver' key present: {b'resolver' in raw}")
    try:
        mp.check_manifest_pins(root=a.snapshot)
        print("check_manifest_pins(snapshot): ACCEPTED")
    except Exception as e:  # noqa: BLE001
        first = str(e).splitlines()[0]
        print(f"check_manifest_pins(snapshot): REFUSED {type(e).__name__}: {first}")


if __name__ == "__main__":
    main()
