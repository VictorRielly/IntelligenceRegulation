#!/usr/bin/env python3
"""ROUND 9: the RUN gate at the 125M shape, one stage at a time.

    python3 scripts/zk60_native_rg_m125.py \
      --bundle /home/victor/zk60-artifacts/m125-capture-dense-l2 \
      --other  /home/victor/zk60-artifacts/m125-capture-zero-l2 \
      --stages load,replay,hash,terminals,commitments,boundary,preimage \
      --evidence results/zk60_native_run_gate_m125 --name m125-dense

WHY THIS EXISTS AND `zk60_native_run_gate.py --bundle ...` DOES NOT SUFFICE.

At the development shapes the whole gate is ten to twenty-five seconds and a
monolithic run is the right shape for it.  At 125M nobody knows what any
stage costs: `A` has 5,681 rows against 623, a message is 16,384 positions
against 1,024, a column is 56,960 bytes against 4,984, and a public table
runs to 2^22 entries.  A single run that dies in its eighth minute tells you
nothing about the seven stages that had already passed.

So this driver calls the gate's OWN stage functions -- imported, not copied;
a test asserts each is the gate module's object -- one at a time, writes the
partial record and a timing line to disk after each, and measures the
process's peak resident set before and after.  A stage that RAISES is caught,
recorded with its traceback's last line, and the driver goes on: a stage this
gate cannot afford at this shape must be reported as unaffordable, not as a
missing file.  `--stages` selects, so an expensive one can be enqueued on its
own.

NOTHING HERE IS A PRIVACY STATEMENT and nothing here is a new check: every
figure is computed by the same function that computed it at the development
shapes.
"""

from __future__ import annotations

import argparse
import json
import os
import resource
import sys
import time
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import zk60_native_run_gate as G  # noqa: E402
from zk60_native_rg_bundle import RunBundle, integrity  # noqa: E402
from zk60_native_rg_hashlayer import check_hash_layer  # noqa: E402
from zk60_native_rg_joint import discover_shared_planes  # noqa: E402
from zk60_native_rg_predict import predict  # noqa: E402
from zk60_native_rg_preimage import preimages  # noqa: E402
from zk60_native_rg_replay import RunReplay  # noqa: E402
from zk60_native_rg_runpins import check_run_layer_pins  # noqa: E402

# The gate functions this driver calls rather than re-implements.  A test
# asserts each name here IS the gate module's object.
FROM_THE_GATE = ("stage3", "stage4", "stage8", "stage10", "stage11",
                 "stage12", "channels", "tool_hashes")

ORDER = ("load", "replay", "hash", "terminals", "commitments", "boundary",
         "preimage", "fullpreimage", "mask", "joint", "channels")


def rss_mb() -> float:
    return resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024.0


class Driver:
    def __init__(self, bundle_dir, evidence, name, other_dir=None,
                 controls=False, only=()):
        self.only = tuple(only)
        self.dir = bundle_dir
        self.evidence = evidence
        self.name = name
        self.other_dir = other_dir
        self.controls = controls
        os.makedirs(evidence, exist_ok=True)
        self.path = os.path.join(evidence, f"{name}.json")
        self.rec = {
            "gate": "zk60-native-run-gate, staged at the 125M shape",
            "round": 9,
            "privacy_property_established": False,
            "privacy_acceptance": False,
            "what_this_is": "the linear channels of ONE captured private run "
            "at the 125M shape, at that run's real challenges, stage by "
            "stage with each stage's wall clock and the process's peak "
            "resident set",
            "tool_sha256": G.tool_hashes(),
            "timings": [],
        }
        self.views = None
        self.replay = None
        self.shared = None
        self.index = None
        self.bundle = None

    # ------------------------------------------------------------- driving
    def flush(self):
        with open(self.path, "w") as fh:
            json.dump(self.rec, fh, indent=1, sort_keys=True)
            fh.write("\n")

    def step(self, label, key, fn):
        before = rss_mb()
        t0 = time.time()
        try:
            out = fn()
            err = None
        except Exception:  # a stage that cannot run at this shape SAYS SO
            out = None
            err = traceback.format_exc().strip().splitlines()[-1]
        dt = round(time.time() - t0, 1)
        after = rss_mb()
        line = {
            "stage": label,
            "seconds": dt,
            "peak_rss_mb_before": round(before),
            "peak_rss_mb_after": round(after),
            "raised": err,
        }
        self.rec["timings"].append(line)
        if err is not None:
            self.rec[key] = {
                "ok": False,
                "the_stage_raised": err,
                "what_this_means": "this stage did not run at this shape.  "
                "The absence of a figure is not a figure, and nothing here "
                "says the bundle is bad",
                "seconds_before_it_raised": dt,
            }
        else:
            self.rec[key] = out
        self.flush()
        ok = "ok" if (err is None and (out is None or out.get("ok") is not False)) \
            else ("RAISED" if err else "FAIL")
        print(f"[{label:14s}] {dt:8.1f} s   peak RSS {after:7.0f} MB   {ok}"
              + (f"   {err}" if err else ""), flush=True)
        return out

    # -------------------------------------------------------------- stages
    def load(self):
        self.bundle = RunBundle(self.dir)
        self.rec["bundle"] = self.bundle.name
        self.rec["bundle_dir"] = self.bundle.dir
        self.rec["schema"] = self.bundle.schema
        self.rec["blocks"] = self.bundle.blocks
        self.rec["prediction"] = predict(self.bundle)
        self.rec["run_layer_source_pins"] = check_run_layer_pins(self.bundle)
        self.rec["hash_rule"] = {
            k: v for k, v in self.bundle.hash_rule_record.items() if k != "rule"
        }
        return integrity(self.bundle)

    def replay_stage(self):
        self.replay = RunReplay(self.bundle).run()
        return self.replay.summary()

    def hash_stage(self):
        return check_hash_layer(self.bundle)

    def terminals(self):
        out, self.index = G.stage8(self.bundle, self.replay, old=None,
                                   do_controls=self.controls)
        self.rec["stage10_bilinear_group_factor"] = G.stage10(
            self.bundle, self.index, self.replay, do_controls=self.controls)
        return out

    def commitments(self):
        note = dict(self.rec["stage8_plane_index_and_terminals"]
                    ["terminal_identity"])
        note["status"] = self.rec["stage8_plane_index_and_terminals"][
            "channel_status"]
        out, self.views = G.stage3(self.bundle, self.replay, pad_rank=True,
                                   terminal_note=note)
        return out

    def boundary(self):
        self.shared = discover_shared_planes(self.bundle)
        return G.stage4(self.bundle, self.views, self.shared, run_wide=True)

    def preimage(self):
        singles = [k for k, v in self.views.items()
                   if all(len(m) == 1 for m in v.groups)]
        return preimages(self.bundle, self.views, sorted(singles))

    def fullpreimage(self):
        """[ROUND 9] `--only` runs the arm on CHOSEN commitments.

        At the development shapes round 7 ran all ten in 70-77 s and there
        was no reason to select.  At 125M the estimate from round 7's own
        measurements is tens of minutes for an `A` or an `H` and a solved
        matrix of `rows * (n + Q)` Python integers, so the honest order is:
        estimate, measure the cheap ones, then attempt one expensive one
        and report what happened -- not launch all seven and lose the lot."""
        from zk60_native_rg_ahpreimage import full_preimages
        order = [k for k in self.views]
        if self.only:
            missing = [k for k in self.only if k not in order]
            if missing:
                raise ValueError(f"--only names commitments this run has "
                                 f"no view for: {missing}")
            order = [k for k in order if k in self.only]
        out = full_preimages(self.bundle, self.views, names=order)
        out["requested"] = True
        out["commitments_requested"] = order
        out["arm_restricted_to"] = list(self.only) if self.only else None
        if self.controls and not self.only:
            a = next((k for k in order if k.startswith("A@")), None)
            h = next((k for k in order if k.startswith("H@")), None)
            from zk60_native_rg_ahcontrols import ah_controls
            out["controls"] = (ah_controls(self.bundle, self.views,
                                           a_name=a, h_name=h)
                               if a and h else
                               {"skipped": "no A and H pair", "ok": False})
            out["ok"] = out["ok"] and out["controls"].get("ok", False)
        else:
            out["controls"] = {
                "skipped": "the arm was restricted to "
                f"{list(self.only)}" if self.only else "controls not requested",
                "ok": False,
            }
        return out

    def mask(self):
        return G.stage12(self.bundle, self.replay, do_controls=self.controls)

    def joint(self):
        from zk60_native_rg_mjoint import joint_run_preimage
        return joint_run_preimage(
            self.bundle, self.views, self.shared,
            self.rec.get("stage11_full_preimage") or dict(G.FULL_PREIMAGE_OFF),
            self.rec.get("stage12_mask_and_cfs") or dict(G.MASK_CFS_OFF))

    def channels(self):
        for k, default in (("stage11_full_preimage", G.FULL_PREIMAGE_OFF),
                           ("stage12_mask_and_cfs", G.MASK_CFS_OFF)):
            self.rec.setdefault(k, dict(default))
        from zk60_native_rg_mjoint import JOINT_OFF
        self.rec.setdefault("stage13_joint_run_preimage", dict(JOINT_OFF))
        return G.channels(self.bundle, self.rec)

    STAGES = {
        "load": ("stage1_integrity", "load"),
        "replay": ("stage2_transcript_replay", "replay_stage"),
        "hash": ("stage9_hash_layer", "hash_stage"),
        "terminals": ("stage8_plane_index_and_terminals", "terminals"),
        "commitments": ("stage3_per_commitment", "commitments"),
        "boundary": ("stage4_the_boundary", "boundary"),
        "preimage": ("stage5_zero_data_preimage", "preimage"),
        "fullpreimage": ("stage11_full_preimage", "fullpreimage"),
        "mask": ("stage12_mask_and_cfs", "mask"),
        "joint": ("stage13_joint_run_preimage", "joint"),
        "channels": ("stage7_channels", "channels"),
    }

    def run(self, stages):
        for s in stages:
            key, fn = self.STAGES[s]
            self.step(s, key, getattr(self, fn))
        done = [k for k in self.rec if k.startswith("stage")]
        self.rec["stages_run"] = sorted(done)
        self.rec["ok"] = all(
            self.rec[k].get("ok") is not False for k in done
        )
        self.rec["peak_rss_mb"] = round(rss_mb())
        self.rec["total_seconds"] = round(
            sum(t["seconds"] for t in self.rec["timings"]), 1)
        self.rec["what_it_does_not_show"] = [
            "linear channels of ONE captured two-block run at the 125M "
            "shape, at that run's real challenges.  Two runs are not a "
            "distribution and two blocks are not twelve",
            "the hash layer's HIDING is still ARGUED: every OPENED column is "
            "re-hashed and re-authenticated, which says nothing about what "
            "an unopened leaf hides (M-2, M-3)",
            "the joint-law composition for a run is unwritten (O-R2 / G-R4)",
            G.RULING_R3,
            "NOT a privacy acceptance and NOT a privacy property",
        ]
        self.flush()
        return self.rec


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--other")
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--stages", default=",".join(ORDER[:7]))
    ap.add_argument("--controls", action="store_true")
    ap.add_argument("--only", default="",
                    help="for the fullpreimage arm: a comma-separated list "
                    "of commitment keys (A@0, H@1, B0, E-Input, ...)")
    args = ap.parse_args(argv)
    stages = [s.strip() for s in args.stages.split(",") if s.strip()]
    bad = [s for s in stages if s not in Driver.STAGES]
    if bad:
        raise SystemExit(f"unknown stage(s): {bad}; the list is {list(ORDER)}")
    d = Driver(args.bundle, args.evidence, args.name, other_dir=args.other,
               controls=args.controls,
               only=[x.strip() for x in args.only.split(",") if x.strip()])
    rec = d.run(stages)
    print(f"record: {d.path}   total {rec['total_seconds']} s   "
          f"peak RSS {rec['peak_rss_mb']} MB   ok={rec['ok']}")
    return 0 if rec["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
