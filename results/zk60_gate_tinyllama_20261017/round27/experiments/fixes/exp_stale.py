"""fr25 fixes review: the pin set is checked by NAME; is the writer file's own
digest tied to the digest the expected set was derived from?  A copy of a real
registered manifest with run_capture.rs (and separately run.rs) declared at its
W16-era full digest (a file that has no registered D55 writer or registry) is
classified by the fixed code.  In memory only."""
import copy
import json
import sys
import types

sys.dont_write_bytecode = True
S = "/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/fr25-fixes/ops/zkp-mvp/gate-tinyllama/staging_v25/scripts"
sys.path.insert(0, S)
import zk60_native_rg_d55 as D  # noqa: E402
import zk60_native_rg_w16 as W  # noqa: E402
import zk60_native_rg_terminals as T  # noqa: E402

base = json.load(open("/Users/victorrielly/zk60-artifacts/d60_20261102/pg_bundles_r26/d55-r13_rung_h24-s0/manifest.json"))
r19b = W.default_r19b_manifest()
for f in ("src/private_block/run_capture.rs", "src/private_block/run.rs"):
    m = copy.deepcopy(base)
    for p in m["source_pins"]:
        if p["file"] == f:
            p["sha256"] = W.W16_READINGS[f][0]
    pins = W.classify_pins(types.SimpleNamespace(manifest=m), r19b)
    sp = T.check_source_pins(types.SimpleNamespace(manifest=m))
    ps = D.pin_set_check(m)
    # d55_gate :1136-1147: a port refusal fails PINS only when the refused pin is not covered
    refused = [x.split(":")[0].strip() for x in sp.get("pins_that_moved", []) + sp.get("pins_missing_from_the_bundle", [])]
    covered = set(pins["at_r19b_files"]) | set(pins["read_here"])
    not_read = [x for x in refused if x not in covered]
    print(f"{f} declared at its W16-era digest {W.W16_READINGS[f][0][:12]}: read_here {f in pins['read_here']}, "
          f"classify ok {pins['ok']}, terminal-port refusals not read {not_read}, pin_set ok {ps['ok']} -> PINS ok "
          f"{bool(pins['ok'] and not not_read and ps['ok'])}; the set was derived from run_capture.rs {D.RUN_CAPTURE_RS_READ[:12]}")
