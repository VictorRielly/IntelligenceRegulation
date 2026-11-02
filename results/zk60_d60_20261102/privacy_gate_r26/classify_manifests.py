#!/usr/bin/env python3
"""Gate round 26 wiring (2026-11-02): the v25 staging pin classification (`zk60_native_rg_w16.classify_pins`, with
the R26 readings and F-B1's backend rule) on bundle manifests alone -- used for the four OLD D60 bundles (their
manifest copies in ../privacy_gate/bundle_manifests/) and the fresh ones. Usage: classify_manifests.py <manifest.json>..."""
import json
import os
import sys
import types

S = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "ops", "zkp-mvp", "gate-tinyllama", "staging_v25", "scripts")
sys.path.insert(0, os.path.abspath(S))
import zk60_native_rg_w16 as W  # noqa: E402

for path in sys.argv[1:]:
    p = W.classify_pins(types.SimpleNamespace(manifest=json.load(open(path))), W.default_r19b_manifest())
    print(os.path.basename(os.path.dirname(path)), "| pins", p["pins"], "at r19b", p["at_r19b"], "read", len(p["read_here"]),
          "(R26", len(p["readings_r26"]), ") unread", [u["file"] for u in p["unread"]], "| proved_on_gpu", p["backend"]["proved_on_gpu"],
          "admissible", p["backend"]["admissible"], "| PINS ok", p["ok"], "| self-read", p["self_read_pending_independent_check"])
