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
# [ROUND 9j] a STANDALONE shaped block bundle, driven stage by stage exactly
# as a run is: the block layer's pins, integrity and replay header, the
# run family's block analogues; every other stage is the gate's own
from zk60_native_rg_block import (  # noqa: E402
    BlockReplay,
    block_controls,
    block_integrity,
    check_block_layer_pins,
    load_bundle,
)
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
         "preimage", "fullpreimage", "mask", "joint", "runcontrols",
         "channels")


def rss_mb() -> float:
    return resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024.0


class Driver:
    def __init__(self, bundle_dir, evidence, name, other_dir=None,
                 controls=False, only=(), cross_dir=None):
        self.only = tuple(only)
        self.cross_dir = cross_dir
        self.dir = bundle_dir
        self.evidence = evidence
        self.name = name
        self.other_dir = other_dir
        self.controls = controls
        os.makedirs(evidence, exist_ok=True)
        self.path = os.path.join(evidence, f"{name}.json")
        self.rec = {
            # [TINYLLAMA PORT] the shape is named from the bundle at load;
            # this placeholder never survives a run that loads one
            "gate": "zk60-native-run-gate, staged (shape named at load)",
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
        # [TINYLLAMA PORT, tools v4] a stage whose ONLY false conjunct is a
        # control family this pass did not request is printed ARMS-ONLY, not
        # FAIL; its `ok` stays false (zk60_native_rg_status, rule (b)/(c))
        if ok == "FAIL":
            from zk60_native_rg_status import explain
            if explain(self.rec, f"/{key}/ok", self.controls):
                ok = "ARMS-ONLY (arm closed; controls not requested; ok=false kept)"
        print(f"[{label:14s}] {dt:8.1f} s   peak RSS {after:7.0f} MB   {ok}"
              + (f"   {err}" if err else ""), flush=True)
        return out

    # -------------------------------------------------------------- stages
    def load(self):
        self.bundle = load_bundle(self.dir)
        block = getattr(self.bundle, "standalone", False)
        self.rec["bundle"] = self.bundle.name
        self.rec["bundle_dir"] = self.bundle.dir
        self.rec["schema"] = self.bundle.schema
        self.rec["blocks"] = self.bundle.blocks
        # [TINYLLAMA PORT 2026-10-17] the record names the shape it read
        # instead of the literal "125M" the 125M round wrote; a bundle
        # whose shape declares a trained calibration also records it
        shape_name = self.bundle.run["shape"]["name"]
        self.rec["gate"] = f"zk60-native-run-gate, staged at the shape {shape_name!r}"
        self.rec["shape_name"] = shape_name
        self.rec["what_this_is"] = (
            "the linear channels of ONE captured private run at the shape "
            f"{shape_name!r}, at that run's real challenges, stage by stage "
            "with each stage's wall clock and the process's peak resident set")
        if self.bundle.run["shape"].get("trained_calibration") is True:
            from zk60_native_rg_terminals import Calibration
            self.rec["trained_calibration"] = Calibration(
                self.bundle.run["shape"]).record()
        self.rec["prediction"] = predict(self.bundle)
        if block:
            self.rec["standalone_block"] = True
            self.rec["what_this_is"] = (
                "the linear channels of ONE captured STANDALONE private block "
                f"({self.bundle.profile}), at that proof's real challenges, "
                "stage by stage with each stage's wall clock and the "
                "process's peak resident set")
            self.rec["block_layer_source_pins"] = check_block_layer_pins(
                self.bundle)
        else:
            self.rec["run_layer_source_pins"] = check_run_layer_pins(self.bundle)
        self.rec["hash_rule"] = {
            k: v for k, v in self.bundle.hash_rule_record.items() if k != "rule"
        }
        return block_integrity(self.bundle) if block else integrity(self.bundle)

    def replay_stage(self):
        self.replay = (BlockReplay(self.bundle)
                       if getattr(self.bundle, "standalone", False)
                       else RunReplay(self.bundle)).run()
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
        # Stage 8 need not have been run: a preimage probe does not want to
        # pay 105 s for the terminal identity first.  Without it the note is
        # the gate's own "open" default, which is what a record with no
        # stage 8 must say.
        s8 = self.rec.get("stage8_plane_index_and_terminals")
        if s8 and "terminal_identity" in s8:
            note = dict(s8["terminal_identity"])
            note["status"] = s8["channel_status"]
        else:
            note = dict(G.PER_SLOT_TERMINAL_OPEN)
            note["why_open"] = ("stage 8 was not run in this pass; see the "
                                "record of record for this bundle")
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

    def runcontrols(self):
        """C1-C6 (round 1), CH-1..CH-7 (rounds 3 and 5) and round 9's own
        M9-1..M9-3.  The stage-8 and stage-10 control families (CT-1..CT-8,
        GQ-1..GQ-7) are fired by `--controls` inside their own stages."""
        from zk60_native_rg_controls import controls as run_controls
        from zk60_native_rg_hcontrols import hash_rule_controls
        from zk60_native_rg_m125controls import m125_controls
        out = {}
        other = load_bundle(self.other_dir) if self.other_dir else None
        if getattr(self.bundle, "standalone", False):
            # [ROUND 9j] the run family's block analogues
            out["run_controls"] = block_controls(
                self.bundle, other, self.views, self.replay, self.shared)
        else:
            out["run_controls"] = (
                run_controls(self.bundle, other, self.views, self.replay,
                             self.shared)
                if other is not None else
                {"skipped": "the swapped-stage control needs a second bundle",
                 "ok": False})
        cross = None
        if self.cross_dir:
            cross = load_bundle(self.cross_dir)
        out["hash_rule_controls"] = hash_rule_controls(
            self.bundle, legacy_bundle=None, cross_profile_bundle=cross)
        out["round_9_controls"] = m125_controls(
            self.bundle, index=self.index, replay=self.replay)
        out["ok"] = all(v.get("ok") for v in out.values()
                        if isinstance(v, dict))
        return out

    def channels(self):
        """`G.channels` is a SUMMARY of the other stages, so a pass that did
        not run one of them cannot be handed a partial record -- that is
        finding K4-F1's lesson and the gate keeps it by suspending the
        channel table whenever anything is suspended.  Here the same rule
        applies to a pass that simply did not ASK for a stage: the stage-8
        stand-in says the terminal identity was not run in THIS pass and
        names the record of record that has it, so no channel is graded off
        a check that did not happen."""
        for k, default in (("stage11_full_preimage", G.FULL_PREIMAGE_OFF),
                           ("stage12_mask_and_cfs", G.MASK_CFS_OFF)):
            self.rec.setdefault(k, dict(default))
        from zk60_native_rg_mjoint import JOINT_OFF
        self.rec.setdefault("stage13_joint_run_preimage", dict(JOINT_OFF))
        s8 = self.rec.get("stage8_plane_index_and_terminals")
        if s8 is None or "terminal_identity" not in s8:
            note = dict(G.PER_SLOT_TERMINAL_OPEN)
            note["checked"] = False
            note["slots_checked"] = 0
            note["reason"] = (
                "stage 8 was NOT RUN in this pass; it is not a refusal and "
                f"not a failure -- see the record of record for "
                f"{self.rec.get('bundle')}, where the terminal identity is "
                "checked for every slot of every stage")
            self.rec["stage8_plane_index_and_terminals"] = {
                "plane_index": {"present": False,
                                "reason": "not read in this pass"},
                "terminal_identity": note,
                "controls": {"skipped": "stage 8 was not run in this pass"},
                "channel_status": "open",
                "not_run_in_this_pass": True,
                "ok": True,
            }
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
        "runcontrols": ("stage6_negative_controls", "runcontrols"),
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
        block = getattr(self.bundle, "standalone", False)
        # [ROUND 9m] the run sentence said "two-block" as a literal; a
        # twelve-block run gets its own (a two-block record keeps its bytes)
        # [TINYLLAMA PORT] the shape's own name, not the literal "125M"
        at = (" at the 125M shape" if "125M" in self.rec.get("shape_name", "125M")
              else f" at the shape {self.rec.get('shape_name')!r}")
        two = (f"linear channels of ONE captured two-block run{at}, at that "
               "run's real challenges.  Two runs are not a "
               "distribution and two blocks are not twelve")
        many = (f"linear channels of ONE captured {self.bundle.blocks}-block "
                f"run{at}, at that run's real challenges.  One "
                "run is not a distribution, and a dense and an all-zero run "
                "are two witnesses, not the space of witnesses")
        self.rec["what_it_does_not_show"] = [
            ("linear channels of ONE captured STANDALONE block proof at its "
             "real challenges.  One proof is not a distribution, and a block "
             "is not a run: nothing here is about a boundary, a segment or "
             "twelve blocks" if block else
             two if self.bundle.blocks == 2 else many),
            "the hash layer's HIDING is still ARGUED: every OPENED column is "
            "re-hashed and re-authenticated, which says nothing about what "
            "an unopened leaf hides (M-2, M-3)",
            # [ROUND 9j, CORRECTED 2026-09-23] was "the joint-law composition
            # for a run is unwritten (O-R2 / G-R4)" -- Theorem B was written
            # and accepted as a reduction on 2026-09-20
            "the joint LAW (Theorem B) is a reduction accepted on paper, "
            "conditional on G-R1 / G-R2 / G-R4, not a computation of this "
            "gate: what is computed is a rank",
            G.RULING_R3,
            "NOT a privacy acceptance and NOT a privacy property",
        ]
        self.flush()
        # [TINYLLAMA PORT, tools v4] the record's STATUS beside its `ok`, in a
        # side file so that no record gains a leaf: PASS / ARMS-ONLY / NOT-OK
        # (`zk60_native_rg_status`); `ok` is never changed
        from zk60_native_rg_status import status_record
        self.status = status_record(self.path, controls_requested=self.controls)
        self.status_path = os.path.join(self.evidence, f"{self.name}.status.json")
        with open(self.status_path, "w") as fh:
            json.dump(self.status, fh, indent=1, sort_keys=True)
            fh.write("\n")
        return self.rec


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--bundle", required=True)
    ap.add_argument("--other")
    ap.add_argument("--cross-profile",
                    help="a bundle of a DIFFERENT tagged profile, for CH-7")
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
               only=[x.strip() for x in args.only.split(",") if x.strip()],
               cross_dir=args.cross_profile)
    rec = d.run(stages)
    print(f"record: {d.path}   total {rec['total_seconds']} s   "
          f"peak RSS {rec['peak_rss_mb']} MB   ok={rec['ok']}")
    # [TINYLLAMA PORT, tools v4] exit 3 = ARMS-ONLY (ok false ONLY because the
    # pass did not request controls), distinct from 1 = anything else
    print(f"status: {d.status['status']}   unexplained false leaves "
          f"{len(d.status['unexplained'])}   -> {d.status_path}")
    if rec["ok"]:
        return 0
    return 3 if d.status["status"] == "ARMS-ONLY" else 1


if __name__ == "__main__":
    raise SystemExit(main())
