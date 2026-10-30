"""Stage 1: re-derive the whole Fiat-Shamir transcript of a native capture.

Every challenge the analysis of stages 2-4 uses is re-derived here with
BLAKE3 from the capture's PUBLIC data, following, label by label,

    hashline/src/private_block/protocol.rs   (transcript, absorb_root,
                                              verify_inner)
    hashline/src/private_attention/protocol.rs (the same, no calibration)
    zkp-core/src/sumcheck.rs::verify         (b"sc-round" + one challenge)
    hashline/src/zk.rs::mask_verify          (theta, b"mask-q", rhos,
                                              b"mask-prox", indices)
    zkp-core/src/pcs.rs::verify_zk           (lambdas per group, prox rho,
                                              b"pcs-vec" x groups,
                                              b"pcs-prox", indices)

A checkpoint is the pair (32-byte state, the next Fp2 challenge), exactly as
`native_capture.rs::state` writes it, so a counter mismatch is detected as
well as a state mismatch.  Every failure is reported, never raised past the
caller: this stage is allowed to FAIL.
"""

from __future__ import annotations

import hashlib

from zk60_native_jv_capture import (
    CALIBRATION_PREIMAGE,
    ENC_COLS,
    LABELS,
    LOG_COLS,
    MASK_LOG_DOM,
    MASK_Q,
    NUM_COL_CHECKS,
    PARAMETERS,
    ROLE_ORDER,
)
from zk60_native_jv_field import Transcript, f2_from_list


class Replay:
    """The replayed transcript of one capture, plus every failure it found."""

    def __init__(self, capture):
        self.cap = capture
        self.failures: list[str] = []
        self.checkpoints = 0
        self.challenges = 0
        self.rho = {}  # slot -> list of Fp2 sumcheck challenges
        self.slot_c = {}  # slot -> the CFS mask challenge c_s
        self.theta = None
        self.mask_prox_rhos = None
        self.mask_indices = None
        self.role_lambdas = {}  # role -> list of per-group lambda lists
        self.role_prox_rhos = {}
        self.role_indices = {}
        self.logup = None
        self.final_counter = None

    # ------------------------------------------------------------- helpers
    def _fail(self, what: str) -> None:
        self.failures.append(what)

    def _check_state(self, tr: Transcript, captured: dict, what: str) -> None:
        self.checkpoints += 1
        if list(tr.state) != captured["state"]:
            self._fail(f"{what}: transcript state differs")
        if list(tr.peek_next()) != captured["next"]:
            self._fail(f"{what}: next challenge differs (state or counter)")

    def _eq_f2(self, got, want, what: str) -> None:
        self.challenges += 1
        if list(got) != list(want):
            self._fail(f"{what}: challenge differs")

    # ---------------------------------------------------------------- run
    def run(self) -> "Replay":
        cap = self.cap
        d = cap.doc
        prof = cap.profile
        slot_label, scalar_label, term_label = LABELS[prof]

        tr = Transcript(domain=prof.encode())
        tr.absorb(b"expected-IO", bytes(d["expected_policy"]))
        if hashlib.sha256(bytes(d["expected_policy"])).hexdigest() != d["expected_policy_sha256"]:
            self._fail("expected policy: sha256 differs from the capture's own digest")
        tr.absorb(b"public-statement", bytes(d["public_statement_digest"]))
        tr.absorb(b"parameters", PARAMETERS[prof])
        pre = CALIBRATION_PREIMAGE[prof]
        if pre is not None:
            import blake3

            tr.absorb(b"calibration", blake3.blake3(pre).digest())
        tr.absorb(b"schedule", bytes(d["schedule_digest"]))
        self._check_state(tr, d["header"], "header")

        # A root, M root, the three LogUp challenges, H root
        a = cap.role("A")
        tr.absorb(b"A", bytes(a["commitment"]["root"]))
        tr.absorb_u64(b"rows", a["commitment"]["rows"])
        tr.absorb_u64(b"log-cols", LOG_COLS)
        tr.absorb(b"M", bytes(cap.mask["root"]))
        logup = tr.challenge_fp2_vec(3)
        for i, (got, want) in enumerate(zip(logup, d["logup_challenges"])):
            self._eq_f2(got, want, f"LogUp challenge {i}")
        self.logup = logup
        h = cap.role("H")
        tr.absorb(b"H", bytes(h["commitment"]["root"]))
        tr.absorb_u64(b"rows", h["commitment"]["rows"])
        tr.absorb_u64(b"log-cols", LOG_COLS)

        # the slots
        for arg in cap.slots:
            s = arg["slot"]
            self._check_state(tr, arg["before_definition"], f"slot {s} before_definition")
            for i, want in enumerate(arg["definition_challenges"]):
                self._eq_f2(tr.challenge_fp2(), want, f"slot {s} definition draw {i}")
            self._check_state(tr, arg["before"], f"slot {s} before")
            tr.absorb_u64(slot_label, s)
            c = tr.challenge_fp2()
            self._eq_f2(c, arg["c"], f"slot {s} mask challenge c")
            self.slot_c[s] = f2_from_list(arg["c"])
            tr.absorb_fp2(scalar_label, [f2_from_list(arg["scalar"])])
            rhos = []
            for j, rnd in enumerate(arg["rounds"]):
                tr.absorb_fp2(b"sc-round", [f2_from_list(v) for v in rnd])
                r = tr.challenge_fp2()
                self._eq_f2(r, arg["rho"][j], f"slot {s} round {j} challenge")
                rhos.append(r)
            if len(rhos) != len(arg["rho"]):
                self._fail(f"slot {s}: {len(rhos)} rounds for {len(arg['rho'])} challenges")
            self.rho[s] = rhos
            tr.absorb_fp2(term_label, [f2_from_list(v) for v in arg["terminals"]])
            self._check_state(tr, arg["after"], f"slot {s} after")

        # the M (masking-commitment) opening
        m = cap.mask
        self._check_state(tr, m["before"], "M before")
        theta = tr.challenge_fp2()
        self._eq_f2(theta, m["theta"], "M theta")
        self.theta = theta
        tr.absorb_fp2(b"mask-q", [f2_from_list(v) for v in m["q"]])
        rhos = tr.challenge_fp2_vec(2 * len(m["specs"]) + 2)
        for i, want in enumerate(m["proximity_rhos"]):
            self._eq_f2(rhos[i], want, f"M proximity rho {i}")
        self.mask_prox_rhos = rhos
        tr.absorb_fp2(b"mask-prox", [f2_from_list(v) for v in m["prox"]])
        idx = tr.challenge_indices(MASK_Q, 1 << MASK_LOG_DOM)
        got = [c["index"] for c in m["columns"]]
        if idx != got:
            self._fail("M sampled column indices differ")
        self.mask_indices = idx
        self._check_state(tr, m["after"], "M after")

        # the four PCS openings, in the capture's declared order
        if [r["role"] for r in cap.roles] != ROLE_ORDER:
            self._fail(f"role order {[r['role'] for r in cap.roles]} != {ROLE_ORDER}")
        for role in cap.roles:
            nm = role["role"]
            self._check_state(tr, role["before"], f"{nm} before")
            lams = []
            for gi, g in enumerate(role["groups"]):
                lam = tr.challenge_fp2_vec(len(g["members"]))
                for k, want in enumerate(g["lambdas"]):
                    self._eq_f2(lam[k], want, f"{nm} group {gi} lambda {k}")
                lams.append(lam)
            self.role_lambdas[nm] = lams
            prox = tr.challenge_fp2_vec(role["commitment"]["rows"])
            for i, want in enumerate(role["proximity_rhos"]):
                self._eq_f2(prox[i], want, f"{nm} proximity rho {i}")
            self.role_prox_rhos[nm] = prox
            for g in role["groups"]:
                tr.absorb_fp2(b"pcs-vec", [f2_from_list(v) for v in g["vector"]])
            tr.absorb_fp2(b"pcs-prox", [f2_from_list(v) for v in role["proximity_vector"]])
            idx = tr.challenge_indices(NUM_COL_CHECKS, ENC_COLS)
            if idx != [c["index"] for c in role["columns"]]:
                self._fail(f"{nm}: sampled column indices differ")
            self.role_indices[nm] = idx
            self._check_state(tr, role["after"], f"{nm} after")

        self.final_counter = tr.counter
        return self

    # -------------------------------------------------------------- report
    def summary(self) -> dict:
        return {
            "capture": self.cap.proof_sha256,
            "profile": self.cap.profile,
            "checkpoints_checked": self.checkpoints,
            "challenges_checked": self.challenges,
            "final_counter": self.final_counter,
            "failures": self.failures,
            "ok": not self.failures,
        }
