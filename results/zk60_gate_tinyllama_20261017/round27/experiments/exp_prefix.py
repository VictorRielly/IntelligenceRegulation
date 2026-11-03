"""fr25 experiment: (a) is a moved pin admitted on a 12-hex PREFIX through
W16_READINGS where round 26 has no reading at that prefix?  (b) do the D55
PINS controls P-1 / P-2 count as fired when there is no object?  (c) is a
CPU-labelled bundle that pins no Metal file admissible?  In-memory manifests
only."""
import sys
import types

S = "/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/staging_v25/scripts"
sys.path.insert(0, S)
import zk60_native_rg_w16 as W  # noqa: E402
import zk60_native_rg_r26readings as R26  # noqa: E402
import zk60_native_rg_d55 as D  # noqa: E402

r19b = W.default_r19b_manifest()


def cls(pins, gpu=False):
    m = {"source_pins": [{"file": f, "sha256": d} for f, d in pins], "proved_on_gpu": gpu}
    return W.classify_pins(types.SimpleNamespace(manifest=m), r19b)


print("W16 prefix-only entries (no R26 reading at the same prefix):",
      [(f, p) for f, (p, _t) in W.W16_READINGS.items() if (f, p) not in R26.R26_READINGS])
for f in ("src/private_block/run.rs", "src/private_block/run_capture.rs"):
    twin = W.W16_READINGS[f][0] + "0" * 52          # 48 bits equal, the rest arbitrary
    p = cls([(f, twin)])
    print(f"(a) {f} @ {twin[:16]}..: read_here={p['read_here']} unread={[u['file'] for u in p['unread']]} ok={p['ok']}")
m = {"source_pins": [{"file": "src/private_block/run.rs", "sha256": "ab" * 32}], "proved_on_gpu": False}
c = D.pin_controls(types.SimpleNamespace(manifest=m), r19b)
print("(b) PINS controls with no R26-read pin:", {k: (v.get("fires"), v.get("no_object")) for k, v in c["controls"].items()}, "ok", c["ok"])
p = cls([("src/private_block/run.rs", R26.R26_READINGS[("src/private_block/run.rs", "0a8f261578cb")][0])], gpu=False)
print("(c) proved_on_gpu false, Metal files not pinned: admissible", p["backend"]["admissible"], "ok", p["ok"],
      "sources", p["backend"]["gpu_backend_sources"])
