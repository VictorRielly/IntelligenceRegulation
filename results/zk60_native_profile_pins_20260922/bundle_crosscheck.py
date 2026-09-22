#!/usr/bin/env python3
"""Round 9h, U2: the three new pins, cross-checked against three independent
sources rather than against the tool that holds them.

    python3 results/zk60_native_profile_pins_20260922/bundle_crosscheck.py

  1 the integrator's main branch at `4751b93` -- the pin of record's source;
  2 the block lane's tip `a8e4939` -- to see whether the integration will
    have to move the pin (round 9f's manifests did; these three do not);
  3 the DELIVERED new-tree bundle's `source_hashes`
    (`results/zk60_native_d22_replay_20260922/bundle/validation.json`, the
    132-entry manifest round 9d replayed).  That file is a delivered
    artifact, read-only and not committed on this lane; it is read here only
    so the reading can be written down.

Nothing is written outside this directory.
"""
import hashlib
import json
import os
import subprocess
import sys

ROOT = "/home/victor/wt-zk60-jointview"
MAIN = "/home/victor/IntelligenceRegulation"
LANE = "/home/victor/wt-zk60-block125m"
BUNDLE = os.path.join(
    ROOT, "results/zk60_native_d22_replay_20260922/bundle/validation.json")

sys.path.insert(0, os.path.join(ROOT, "scripts"))
import zk60_native_profile_pins as pp  # noqa: E402


def git_sha(tree, ref, path):
    out = subprocess.run(
        ["git", "--no-pager", "-C", tree, "show", f"{ref}:{path}"],
        check=True, capture_output=True).stdout
    return hashlib.sha256(out).hexdigest()


def main():
    bundle = {}
    if os.path.exists(BUNDLE):
        bundle = json.load(open(BUNDLE)).get("source_hashes", {})
        print(f"bundle manifest: {BUNDLE}\n  {len(bundle)} source hashes")
    else:
        print(f"bundle manifest ABSENT at {BUNDLE} (delivered artifact, "
              "untracked); columns 3 and 4 will say so")
    print()
    bad = 0
    for pin in pp.PROFILE_PINS:
        here = hashlib.sha256(
            open(os.path.join(ROOT, pin.path), "rb").read()).hexdigest()
        main_sha = git_sha(MAIN, "4751b93", pin.path)
        lane_sha = git_sha(LANE, "a8e4939", pin.path)
        bund = bundle.get(pin.path, "(absent)")
        print(pin.path)
        print(f"  pin of record      {pin.sha256}")
        print(f"  main   4751b93     {main_sha}  {'==' if main_sha == pin.sha256 else '!='}")
        print(f"  lane   a8e4939     {lane_sha}  {'==' if lane_sha == pin.sha256 else '!='}")
        print(f"  this worktree      {here}  {'==' if here == pin.sha256 else '!='}")
        print(f"  delivered bundle   {bund}  "
              f"{'==' if bund == pin.sha256 else ('n/a' if bund == '(absent)' else '!=')}")
        for got in (main_sha, lane_sha, here):
            if got != pin.sha256:
                bad += 1
        if bundle and bund != pin.sha256:
            bad += 1
        print()
    print("VERDICT:", "every source agrees with the pin of record" if not bad
          else f"{bad} disagreement(s)")
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
