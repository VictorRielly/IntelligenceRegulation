#!/usr/bin/env python3
"""O13 -- the /2 transcript schedule, reconstructed and cross-checked.

Reviewer: Claude Opus 5, 2026-09-09 (task O13 of docs/zkmatrix-poc/ZK60_OPUS_QUEUE.md).

This is a SCHEDULE INVENTORY, not a cryptographic construction and not an
adaptive privacy theorem.  It states, for every public observation class of the
`ffn-v3-mr1-fresh-io-poc/2` profile, when it becomes public, which earlier
public values and challenges determine it, which hidden variables it still
depends on, and what a simulator must already have fixed at that point.

Every ordering claim is taken from the verifier source and then cross-checked
against the four round-22 captures.  Challenge VALUES are not recomputed: that
needs BLAKE3, which is not available here and is unprogrammable in any case.
What is checked is structural -- segment contiguity through the recorded
transcript states, the peeked next-challenge identity, slot/argument geometry
and every declared count.

    python3 scripts/zk60_opus_adaptive_schedule.py --captures DIR --out FILE
"""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# (site, label, kind) in verifier order.  Line numbers are hashline/src/zk.rs
# unless prefixed, and were read at review baseline b3a2535.
SCHEDULE = [
    ("zk_ffn_fresh_io.rs:139", "Transcript::new(PROFILE)", "init"),
    ("zk_ffn_fresh_io.rs:140", 'absorb "expected-IO" (112-byte policy: magic, context, '
     "two scales, input root, output root)", "absorb"),
    ("zk_ffn_fresh_io.rs:141", 'absorb "parameters" (fixed geometry string)', "absorb"),
    ("zk.rs:3501", "absorb_statement_v3(st)", "absorb"),
    ("zk.rs:3507", 'absorb "zk" mode header', "absorb"),
    ("zk.rs:3518", 'absorb_com "W"', "absorb"),
    ("zk.rs:3519", 'absorb_com "A"', "absorb"),
    ("zk.rs:3521", 'absorb "M" (the single CFS mask root, all eight slots)', "absorb"),
    ("zk.rs:3522", "challenge beta", "squeeze"),
    ("zk.rs:3523", "challenge gamma", "squeeze"),
    ("zk.rs:3524", "challenge alpha", "squeeze"),
    ("zk.rs:3525", 'absorb_com "H" (AFTER beta/gamma/alpha)', "absorb"),
    ("zk.rs:3536-3542", "gu challenges r_i, r_j, lam_gu, lam_f, c_gu", "squeeze"),
    ("zk.rs:3543", 'absorb "gu-claim"', "absorb"),
    ("zk.rs:3544-3568", "gu masked sumcheck rounds (6)", "rounds"),
    ("zk.rs:3569", 'absorb "gu-term"', "absorb"),
    ("zk.rs:3576-3581", "d challenges r_ip, r_jp, lam_d, c_d", "squeeze"),
    ("zk.rs:3582", 'absorb "d-claim"', "absorb"),
    ("zk.rs:3583-3597", "d masked sumcheck rounds (6)", "rounds"),
    ("zk.rs:3598", 'absorb "d-term"', "absorb"),
    ("zk.rs:3605-3608", "zc20 challenges tau, mu, nu0, c_f", "squeeze"),
    ("zk.rs:3609", 'absorb "gammaF"', "absorb"),
    ("zk.rs:3610-3634", "zc20 masked sumcheck rounds (10)", "rounds"),
    ("zk.rs:3635", 'absorb "zcF-term"', "absorb"),
    ("zk.rs:3638-3641", "zc17 challenges tau2, mu2, nu_z, c_dz", "squeeze"),
    ("zk.rs:3642", 'absorb "gammaD"', "absorb"),
    ("zk.rs:3643-3661", "zc17 masked sumcheck rounds (10)", "rounds"),
    ("zk.rs:3662", 'absorb "zcD-term"', "absorb"),
    ("zk.rs:3665-3667", "tab challenges tau3, mu3, c_tab", "squeeze"),
    ("zk.rs:3668", 'absorb "gamma-tab"', "absorb"),
    ("zk.rs:3669-3686", "tab masked sumcheck rounds (17)", "rounds"),
    ("zk.rs:3687", 'absorb "tab-term"', "absorb"),
    ("zk.rs:3690", "zs challenge c_zs", "squeeze"),
    ("zk.rs:3691", 'absorb "gamma-zs"', "absorb"),
    ("zk.rs:3692-3695", "zs masked sumcheck rounds (9)", "rounds"),
    ("zk.rs:3696", 'absorb "zs-term"', "absorb"),
    ("zk.rs:3739", "before_openings callback -> verify_arguments", "callback"),
    ("zk_ffn_fresh_io.rs:385", 'absorb "io-side" 0', "absorb"),
    ("zk_ffn_fresh_io.rs:386", "IO side 0: challenge tau (9)", "squeeze"),
    ("zk_ffn_fresh_io.rs:387", "IO side 0: challenge c via draw_mask_challenge; c == 0 ABORTS "
     "(zk_ffn_fresh_poc.rs:228-231), one squeeze, no resampling", "squeeze"),
    ("zk_ffn_fresh_io.rs:388", 'absorb "io-gamma" = c * mask[slot 6].total()', "absorb"),
    ("zk_ffn_fresh_io.rs:389", "IO side 0: sumcheck::verify(gamma, 2, 10) -- 10 rounds, 10 rho", "rounds"),
    ("zk_ffn_fresh_io.rs:392-394", "IO side 0: rho[9] == 0 ABORTS (zero terminal mask challenge)", "guard"),
    ("zk_ffn_fresh_io.rs:385", 'absorb "io-side" 1', "absorb"),
    ("zk_ffn_fresh_io.rs:386", "IO side 1: challenge tau (9)", "squeeze"),
    ("zk_ffn_fresh_io.rs:387", "IO side 1: challenge c via draw_mask_challenge; c == 0 ABORTS", "squeeze"),
    ("zk_ffn_fresh_io.rs:388", 'absorb "io-gamma" = c * mask[slot 7].total()', "absorb"),
    ("zk_ffn_fresh_io.rs:389", "IO side 1: sumcheck::verify(gamma, 2, 10) -- 10 rounds, 10 rho", "rounds"),
    ("zk_ffn_fresh_io.rs:392-394", "IO side 1: rho[9] == 0 ABORTS (zero terminal mask challenge)", "guard"),
    ("zk.rs:3742", "M opening: mask_verify (theta, q, proximity rhos, 256 columns)", "open"),
    ("zk.rs:3752-3753", "W opening: check_masks + pcs::verify_zk (P3 private; P1 public root)", "open"),
    ("zk.rs:3768-3769", "A opening: check_masks + pcs::verify_zk", "open"),
    ("zk.rs:3775-3776", "H opening: check_masks + pcs::verify_zk", "open"),
    ("zk_ffn_fresh_io.rs:459,462", "Input endpoint opening: check_masks(7 rows, log_cols 8, "
     "mask rows [2,3], prox 4) then pcs::verify_zk", "open"),
    ("zk_ffn_fresh_io.rs:459,462", "Output endpoint opening: same, second iteration", "open"),
]

# Public observation classes: what a simulator must have fixed at each point.
CLASSES = [
    dict(name="endpoint roots (in the 112-byte policy)", public_at="before every challenge",
         determined_by=["caller-supplied policy"],
         still_depends_on=["both endpoints' 7 rows, pads and 2048 salts"],
         simulator_must_have_fixed=["both endpoint commitments, before any challenge exists"]),
    dict(name="W root", public_at="absorb_com W, before beta/gamma/alpha",
         determined_by=["public weight policy in P1"],
         still_depends_on=["private W rows in P3 only"],
         simulator_must_have_fixed=["P3: the private W commitment; P1: nothing (public root)"]),
    dict(name="A root", public_at="absorb_com A, before beta/gamma/alpha",
         determined_by=[],
         still_depends_on=["all 702 A rows, including the X/z16 planes aliased to the endpoints"],
         simulator_must_have_fixed=["A, consistently with both endpoints' data rows"]),
    dict(name="M root (all eight CFS slots)", public_at="absorb M, before beta/gamma/alpha",
         determined_by=[],
         still_depends_on=["every slot's mask coefficients, including slots 6 and 7"],
         simulator_must_have_fixed=["all eight slots' coefficients before any challenge they will mask"]),
    dict(name="beta, gamma, alpha", public_at="squeezed after M",
         determined_by=["the transcript state after statement, W, A, M"],
         still_depends_on=[], simulator_must_have_fixed=[]),
    dict(name="H root", public_at="absorb_com H, AFTER beta/gamma/alpha",
         determined_by=[],
         still_depends_on=["1326 LogUp helper rows, which are functions of beta/gamma/alpha and the witness"],
         simulator_must_have_fixed=["H after learning beta/gamma/alpha -- the one commitment that may depend on them"]),
    dict(name="per-argument claims and gammas (gu_claim, d_claim, gamma20, gamma17, gamma_tab, gamma_zs)",
         public_at="absorbed before each argument's rounds",
         determined_by=["the argument's batching challenges", "the committed slot total for masked gammas"],
         still_depends_on=["the witness sums being proved"],
         simulator_must_have_fixed=["the slot totals, at M commitment time"]),
    dict(name="masked sumcheck round messages", public_at="one per round, each followed by its challenge",
         determined_by=["the fibre through (claim, fin) for the committed slot"],
         still_depends_on=["the slot's mask coefficients and the witness tables"],
         simulator_must_have_fixed=["the slot coefficients; the round values are then constrained, not free"]),
    dict(name="argument terminals", public_at="absorbed after each argument's rounds",
         determined_by=["the final sumcheck evaluation and the mask evaluation at rho"],
         still_depends_on=["witness values at the final challenge point"],
         simulator_must_have_fixed=[]),
    dict(name="group vectors (message and pad coordinates)", public_at="each role's opening",
         determined_by=["the role's opening challenges"],
         still_depends_on=["every row in the group, masks and pads included"],
         simulator_must_have_fixed=["the committed rows"]),
    dict(name="proximity vectors", public_at="each role's opening",
         determined_by=["one proximity challenge per row"],
         still_depends_on=["every row of the commitment"],
         simulator_must_have_fixed=["the committed rows"]),
    dict(name="sampled column indices", public_at="derived inside each role's opening",
         determined_by=["the transcript state at that opening site"],
         still_depends_on=[],
         simulator_must_have_fixed=["the commitment, whose root was absorbed long before these indices exist"]),
    dict(name="sampled column values, salts and authentication paths", public_at="each role's opening",
         determined_by=["the indices and the committed encoding"],
         still_depends_on=["the encoded rows and the per-column salts"],
         simulator_must_have_fixed=["either the real encoding, or a programmable hash (round 23's device)"]),
]

REJECTION_GUARDS = [
    dict(site="zk_ffn_fresh_poc.rs:228-231", guard="draw_mask_challenge: c == 0 aborts the attempt",
         resamples=False, squeezes_consumed=1, depends_on_witness=False,
         simulator_can_reproduce=True,
         note="an abort on a challenge-only event; no variable-length rejection loop, so the "
              "squeeze counter advances deterministically"),
    dict(site="zk_ffn_fresh_io.rs:392-394", guard="rho[9] == 0 aborts (zero terminal mask challenge)",
         resamples=False, squeezes_consumed=0, depends_on_witness=False,
         simulator_can_reproduce=True,
         note="also challenge-only; both guards are public predicates and leak nothing"),
]

CIRCLES = [
    dict(id="C1", name="commit-then-mask",
         cycle="M root absorbed (zk.rs:3521) -> beta/gamma/alpha and every later challenge "
               "-> the masked round messages those challenges constrain -> the slot "
               "coefficients that had to be inside M",
         why_it_matters="the mask coefficients are fixed before the challenges they must "
                        "satisfy are known",
         known_break="FA8 programs the round challenges at squeeze points; that is a random-oracle "
                     "programming argument, not a plain reduction",
         resolved=False),
    dict(id="C2", name="commit-then-open",
         cycle="endpoint masks and pads -> encoded rows -> Merkle root -> absorbed in the "
               "112-byte policy before everything -> transcript -> opening challenges -> "
               "which columns must be explained -> the masks and pads",
         why_it_matters="round 24 samples masks and pads AFTER fixing which columns are opened; "
                        "in the real schedule the root that binds them is absorbed first",
         known_break="round 23's deferred Merkle preparation issues a root first and programs "
                     "salted leaves later; real BLAKE3 cannot be programmed",
         resolved=False),
    dict(id="C3", name="shared-plane consistency",
         cycle="A rows 14..17 alias Input rows 0..1 and Output rows 0..1 -> both roots are "
               "absorbed before any challenge -> a simulator must fix one shared X/z16 plane "
               "that simultaneously satisfies A's 20 claims over 7 groups and both endpoints' "
               "single claims",
         why_it_matters="round 24 samples one endpoint in isolation and neither resamples nor "
                        "consults A",
         known_break="none; the joint field-view sampler is the open Codex task",
         resolved=False),
    dict(id="C4", name="slot-total to gamma",
         cycle="io gamma = c * mask[slot].total() (zk_ffn_fresh_io.rs:296) -> c is squeezed "
               "immediately before -> the total was fixed at M commitment time",
         why_it_matters="the simulator picks totals blind, and gamma is then forced by a "
                        "challenge it does not control",
         known_break="round 21 checks the conditional fibre at fixed challenges only",
         resolved=False),
]


def load(directory):
    caps = []
    for path in sorted(Path(directory).glob("*.json")):
        caps.append((path, json.loads(path.read_text())))
    if not caps:
        raise SystemExit(f"no captures in {directory}")
    return caps


def segments(cap):
    segs = [("M", cap["mask"])]
    if cap.get("public_w"):
        segs.append(("public_W", cap["public_w"]))
    segs += [(r["role"], r) for r in cap["roles"]]
    return segs


def cross_check(path, cap):
    """Structural checks against one capture. Returns a dict of named booleans."""
    segs = segments(cap)
    names = [n for n, _ in segs]
    contiguous = all(
        segs[i][1]["after"]["state"] == segs[i + 1][1]["before"]["state"]
        for i in range(len(segs) - 1))

    # theta is literally the next challenge peeked from the pre-M-opening state
    theta_is_next = cap["mask"]["before"]["next"] == cap["mask"]["theta"]

    specs = [tuple(s) for s in cap["mask"]["specs"]]
    # every argument's (rounds, degree) must name exactly one reserved slot
    args = [(a["name"], len(a["rounds"]), len(a["rounds"][0]) - 1) for a in cap["ffn_arguments"]]
    args += [(f"io{a['side']}", len(a["rounds"]), len(a["rounds"][0]) - 1) for a in cap["io_arguments"]]
    slot_of = {}
    unmatched = []
    for name, nrounds, degree in args:
        hits = [i for i, s in enumerate(specs) if s == (nrounds, degree) and i not in slot_of.values()]
        if hits:
            slot_of[name] = hits[0]
        else:
            unmatched.append(name)

    io_slots = {f"io{a['side']}": a["slot"] for a in cap["io_arguments"]}
    io_slots_declared = io_slots == {"io0": 6, "io1": 7}
    io_geometry = all(len(a["tau"]) == 9 and len(a["rho"]) == 10 and len(a["rounds"]) == 10
                      and len(a["terminals"]) == 2 for a in cap["io_arguments"])

    mask_rhos = len(cap["mask"]["proximity_rhos"]) == 2 * len(specs) + 2
    # every folded vector carries n message coordinates plus q_pad pad coordinates
    widths = {len(r["proximity_vector"]) for r in cap["roles"]}
    widths |= {len(g["vector"]) for r in cap["roles"] for g in r["groups"]}
    role_vector_width = widths == {(1 << cap["roles"][0]["params"]["log_cols"])
                                   + cap["roles"][0]["q_pad"]}
    role_prox_rhos = all(len(r["proximity_rhos"]) == r["commitment"]["rows"] for r in cap["roles"])

    return dict(
        capture=path.name, privacy=cap["privacy"], proof_sha256=cap["proof_sha256"],
        segment_order=names, declared_opening_order=cap["opening_order"],
        transcript_contiguous=contiguous,
        theta_is_the_peeked_next_challenge=theta_is_next,
        eight_reserved_slots=len(specs) == 8,
        every_argument_matches_one_slot=not unmatched,
        argument_to_slot=slot_of,
        emission_order=[n for n, _, _ in args],
        emission_order_slot_indices=[slot_of.get(n) for n, _, _ in args],
        io_slots_are_6_and_7=io_slots_declared,
        io_geometry_9_tau_10_rho_10_rounds=io_geometry,
        mask_proximity_rhos_is_2s_plus_2=mask_rhos,
        role_vectors_are_n_plus_qpad=role_vector_width,
        role_proximity_rhos_is_one_per_row=role_prox_rhos,
    )


CITED_SOURCES = [
    "hashline/src/zk.rs",
    "hashline/src/zk_ffn_fresh_io.rs",
    "hashline/src/zk_ffn_fresh_poc.rs",
    "zkp-core/src/transcript.rs",
    "zkp-core/src/pcs.rs",
]


def run(directory):
    caps = load(directory)
    checks = [cross_check(p, c) for p, c in caps]
    flags = [k for k in checks[0]
             if isinstance(checks[0][k], bool)]
    summary = {k: all(c[k] for c in checks) for k in flags}
    return dict(
        schema=1,
        task="O13 -- adaptive transcript dependency inventory",
        reviewer="Claude Opus 5, independent reviewer, 2026-09-09 session (O13)",
        review_baseline="b3a253592b9269d7b65359d33efcd1e40d5217ed",
        profile=caps[0][1]["profile"],
        source_commit=caps[0][1]["source_commit"],
        is_a_schedule_inventory_not_a_construction=True,
        adaptive_privacy_theorem_proved=False,
        challenge_values_recomputed=False,
        challenge_values_note="recomputing challenges needs BLAKE3, unavailable here and "
                              "unprogrammable in production; only structural facts are checked",
        schedule=[dict(site=s, event=e, kind=k) for s, e, k in SCHEDULE],
        observation_classes=CLASSES,
        rejection_guards=REJECTION_GUARDS,
        circular_dependencies=CIRCLES,
        unresolved_sampling_steps=[c["id"] + ": " + c["name"] for c in CIRCLES if not c["resolved"]],
        capture_cross_checks=checks,
        all_captures_agree=summary,
        every_structural_check_passes=all(summary.values()),
        tool_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        source_sha256={s: hashlib.sha256((ROOT / s).read_bytes()).hexdigest()
                       for s in CITED_SOURCES},
        capture_sha256={p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                        for p, _ in caps},
        production_changes="none; this task is read-only over the sources it cites",
        full_privacy_review_complete=False,
        u2_closed=False,
        unexpected_disclosure_found=False,
    )


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--captures", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    result = run(args.captures)
    with args.out.open("w") as stream:
        json.dump(result, stream, indent=1)
        stream.write("\n")
    ok = result["every_structural_check_passes"]
    print(("PASS" if ok else "FAIL") +
          f": {len(result['capture_cross_checks'])} captures, "
          f"{len(SCHEDULE)} schedule sites, {len(CLASSES)} observation classes, "
          f"{len(CIRCLES)} unresolved circular dependencies")
    raise SystemExit(0 if ok else 1)


if __name__ == "__main__":
    main()
