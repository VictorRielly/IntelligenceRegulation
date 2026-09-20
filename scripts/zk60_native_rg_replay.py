"""The Fiat-Shamir replay of a WHOLE RUN, in Python, from public data only.

The model is `zk60_native_jv_replay.Replay` (one single-block proof); this is
the same replay for a run of L stages under ONE transcript, with three
differences, all of them DATA rather than ported constants:

* the header is a RUN header -- `run-shape` first, then `expected-IO`,
  `public-statement` (a digest over the L block digests), `parameters` (the
  bundle's own `parameter_line`), `calibration` (the digest itself, not a
  preimage) and `schedule`.  The state at that point is `run_binding`;
* each stage absorbs its two locality words (`pb-run-stage`, `pb-run-block`)
  and, before any challenge of either adjacent equality slot, the boundary
  root under `B` -- then the block family's own A / M / LogUp / H prefix;
* the openings of a stage are `opening_order[1:]`, three in every stage but
  the last, which adds `Output`; the PCS parameters of each opening are read
  from that opening's own `params`.

Sources followed label by label (pinned in `manifest.json["source_pins"]`):
`private_block/run.rs::transcript` and the stage loop, `protocol.rs::
absorb_root` and `verify_inner`, `zkp-core/src/sumcheck.rs::verify`,
`hashline/src/zk.rs::mask_verify`, `zkp-core/src/pcs.rs::verify_zk`.

WHAT IS AND IS NOT RE-DERIVED.  Every challenge of every stage is re-derived
here and compared with the recorded value, and every recorded transcript
position (the stage header, each slot's three positions, the M opening's two,
each PCS opening's two, and the bundle's own `transcript_sites` index) is
compared as the pair (32-byte state, the Fp2 that would be drawn next), so a
counter mismatch is caught as well as a state mismatch.  The segment position
tags (`start_tag`, `end_tag`) are OUTSIDE the chain (ruling M-6) and are
re-derived separately, from a discarded clone, exactly as
`run.rs::position_tag` does.  Nothing in the replay needs a public table's
values, so `public_tables_included: false` costs it nothing.

A failure is recorded and named, never raised: this stage is allowed to FAIL.
"""

from __future__ import annotations

from zk60_native_jv_field import Transcript, f2_bytes, f2_from_list


class RunReplay:
    """The replayed transcript of one run bundle, plus every failure."""

    def __init__(self, bundle):
        self.b = bundle
        self.failures: list[str] = []
        self.checkpoints = 0
        self.challenges = 0
        self.not_rederived: list[str] = []
        # per stage: the challenges the later stages need
        self.stages: list[dict] = [
            {
                "rho": {},
                "slot_c": {},
                "theta": None,
                "mask_prox_rhos": None,
                "mask_indices": None,
                "role_lambdas": {},
                "role_prox_rhos": {},
                "role_indices": {},
                "logup": None,
            }
            for _ in range(bundle.blocks)
        ]
        self.run_binding_ok = None
        self.position_tags = []
        self.final_counter = None

    # ------------------------------------------------------------- helpers
    def _fail(self, what: str) -> None:
        self.failures.append(what)

    def _check_state(self, tr, captured, what: str) -> None:
        self.checkpoints += 1
        if list(tr.state) != captured["state"]:
            self._fail(f"{what}: transcript state differs")
        if list(tr.peek_next()) != captured["next"]:
            self._fail(f"{what}: next challenge differs (state or counter)")

    def _eq_f2(self, got, want, what: str) -> None:
        self.challenges += 1
        if list(got) != list(want):
            self._fail(f"{what}: challenge differs")

    @staticmethod
    def _position_tag(tr) -> list[int]:
        """`run.rs::position_tag`: two Fp2 squeezed from a DISCARDED clone."""
        c = tr.clone()
        v = [c.challenge_fp2(), c.challenge_fp2()]
        return list(f2_bytes(v[0]) + f2_bytes(v[1]))

    @staticmethod
    def _absorb_root(tr, label: bytes, root, rows: int, log_cols: int) -> None:
        tr.absorb(label, bytes(root))
        tr.absorb_u64(b"rows", rows)
        tr.absorb_u64(b"log-cols", log_cols)

    # ----------------------------------------------------------------- run
    def run(self) -> "RunReplay":
        b = self.b
        d = b.run
        sh = b.shape

        tr = Transcript(domain=bytes(d["transcript_domain_bytes"]))
        shape_bytes = b"".join(int(v).to_bytes(8, "little") for v in d["run_shape_words"])
        tr.absorb(b"run-shape", shape_bytes)
        tr.absorb(b"expected-IO", bytes(d["expected_policy"]))
        tr.absorb(b"public-statement", bytes(d["public_statement_digest"]))
        tr.absorb(b"parameters", d["parameter_line"].encode())
        tr.absorb(b"calibration", bytes(d["calibration"]))
        tr.absorb(b"schedule", bytes(d["schedule_digest"]))
        self.run_binding_ok = list(tr.state) == d["run_binding"]
        self.checkpoints += 1
        if not self.run_binding_ok:
            self._fail("run header: the state after the header is not run_binding")

        for st in b.stages:
            self._stage(tr, st)

        self.final_counter = tr.counter
        return self

    # --------------------------------------------------------------- stage
    def _stage(self, tr, st) -> None:
        b = self.b
        sh = b.shape
        k = st.index
        doc = st.doc
        acc = self.stages[k]
        tag = f"stage {k}"

        self._check_state(tr, doc["header"], f"{tag} header")
        start = self._position_tag(tr)
        if start != doc["start_tag"]:
            self._fail(f"{tag}: the segment's start tag is not this transcript position")

        tr.absorb_u64(b"pb-run-stage", k)
        tr.absorb(b"pb-run-block", bytes(doc["block_digest"]))
        bc = doc["boundary_committed"]
        if bc is not None:
            self._absorb_root(tr, b"B", bc["root"], bc["rows"], bc["log_cols"])
        self._absorb_root(tr, b"A", doc["a_root"], doc["a_rows"], doc["log_cols"])
        tr.absorb(b"M", bytes(doc["mask_root"]))
        logup = tr.challenge_fp2_vec(3)
        for i, want in enumerate(doc["logup_challenges"]):
            self._eq_f2(logup[i], want, f"{tag} LogUp challenge {i}")
        acc["logup"] = logup
        self._absorb_root(tr, b"H", doc["h_root"], doc["h_rows"], doc["log_cols"])

        sites = {(s["stage"], s["site"]): s for s in doc["transcript_sites"]}
        want_sites = [f"slot {s:02d}" for s in range(sh.n_slots)] + [
            f"{nm} opening" for nm in doc["opening_order"]
        ]
        if [s["site"] for s in doc["transcript_sites"]] != want_sites:
            self._fail(f"{tag}: the transcript_sites index is not the declared site order")
        if any(s["stage"] != k for s in doc["transcript_sites"]):
            self._fail(f"{tag}: a transcript site names another stage")

        # ------------------------------------------------------- the slots
        for arg in st.slots:
            s = arg["slot"]
            site = sites.get((k, f"slot {s:02d}"))
            if site is None:
                self._fail(f"{tag}: slot {s} is not in the stage's transcript_sites index")
            else:
                # the site index brackets the WHOLE slot: its `before` is the
                # slot's `before_definition`, its `after` the slot's `after`
                self._check_state(tr, site["before"], f"{tag} slot {s} site before")
            self._check_state(tr, arg["before_definition"], f"{tag} slot {s} before_definition")
            for i, want in enumerate(arg["definition_challenges"]):
                self._eq_f2(tr.challenge_fp2(), want, f"{tag} slot {s} definition draw {i}")
            self._check_state(tr, arg["before"], f"{tag} slot {s} before")
            tr.absorb_u64(b"pb-slot", s)
            c = tr.challenge_fp2()
            self._eq_f2(c, arg["c"], f"{tag} slot {s} mask challenge c")
            acc["slot_c"][s] = f2_from_list(arg["c"])
            tr.absorb_fp2(b"pb-scalar", [f2_from_list(arg["scalar"])])
            rhos = []
            for j, rnd in enumerate(arg["rounds"]):
                tr.absorb_fp2(b"sc-round", [f2_from_list(v) for v in rnd])
                r = tr.challenge_fp2()
                self._eq_f2(r, arg["rho"][j], f"{tag} slot {s} round {j} challenge")
                rhos.append(r)
            if len(rhos) != len(arg["rho"]):
                self._fail(f"{tag} slot {s}: {len(rhos)} rounds for {len(arg['rho'])} challenges")
            acc["rho"][s] = rhos
            tr.absorb_fp2(b"pb-term", [f2_from_list(v) for v in arg["terminals"]])
            self._check_state(tr, arg["after"], f"{tag} slot {s} after")
            if site is not None:
                self._check_state(tr, site["after"], f"{tag} slot {s} site after")

        # ------------------------------------------------- the M opening
        m = st.mask
        m_site = sites.get((k, "M opening"))
        if m_site is None:
            self._fail(f"{tag}: the M opening is not in the transcript_sites index")
        elif m_site["before"] != m["before"] or m_site["after"] != m["after"]:
            self._fail(f"{tag}: the M opening's site index differs from its own positions")
        self._check_state(tr, m["before"], f"{tag} M before")
        theta = tr.challenge_fp2()
        self._eq_f2(theta, m["theta"], f"{tag} M theta")
        acc["theta"] = theta
        tr.absorb_fp2(b"mask-q", [f2_from_list(v) for v in m["q"]])
        rhos = tr.challenge_fp2_vec(2 * len(m["specs"]) + 2)
        for i, want in enumerate(m["proximity_rhos"]):
            self._eq_f2(rhos[i], want, f"{tag} M proximity rho {i}")
        acc["mask_prox_rhos"] = rhos
        tr.absorb_fp2(b"mask-prox", [f2_from_list(v) for v in m["prox"]])
        idx = tr.challenge_indices(sh.mask_columns, 1 << sh.mask_log_dom)
        if idx != [c["index"] for c in m["columns"]]:
            self._fail(f"{tag} M: sampled column indices differ")
        acc["mask_indices"] = idx
        self._check_state(tr, m["after"], f"{tag} M after")

        # ----------------------------------------------- the PCS openings
        order = doc["opening_order"]
        if order[0] != "M":
            self._fail(f"{tag}: opening_order does not start at M")
        if [r["role"] for r in st.roles] != order[1:]:
            self._fail(f"{tag}: the roles array does not follow opening_order")
        for role in st.roles:
            nm = role["role"]
            key = st.key(nm)
            r_site = sites.get((k, f"{nm} opening"))
            if r_site is None:
                self._fail(f"{tag}: the {nm} opening is not in the transcript_sites index")
            elif r_site["before"] != role["before"] or r_site["after"] != role["after"]:
                self._fail(f"{tag}: the {nm} opening's site index differs from its positions")
            self._check_state(tr, role["before"], f"{tag} {nm} before")
            lams = []
            for gi, g in enumerate(role["groups"]):
                lam = tr.challenge_fp2_vec(len(g["members"]))
                for j, want in enumerate(g["lambdas"]):
                    self._eq_f2(lam[j], want, f"{tag} {nm} group {gi} lambda {j}")
                lams.append(lam)
            acc["role_lambdas"][key] = lams
            prox = tr.challenge_fp2_vec(role["commitment"]["rows"])
            for i, want in enumerate(role["proximity_rhos"]):
                self._eq_f2(prox[i], want, f"{tag} {nm} proximity rho {i}")
            acc["role_prox_rhos"][key] = prox
            for g in role["groups"]:
                tr.absorb_fp2(b"pcs-vec", [f2_from_list(v) for v in g["vector"]])
            tr.absorb_fp2(b"pcs-prox", [f2_from_list(v) for v in role["proximity_vector"]])
            p = role["params"]
            idx = tr.challenge_indices(p["num_col_checks"], (1 << p["log_cols"]) * p["inv_rate"])
            if idx != [c["index"] for c in role["columns"]]:
                self._fail(f"{tag} {nm}: sampled column indices differ")
            acc["role_indices"][key] = idx
            self._check_state(tr, role["after"], f"{tag} {nm} after")

        end = self._position_tag(tr)
        if end != doc["end_tag"]:
            self._fail(f"{tag}: the segment's end tag is not this transcript position")
        self.position_tags.append({"stage": k, "start_tag_ok": start == doc["start_tag"],
                                   "end_tag_ok": end == doc["end_tag"]})
        if k + 1 < len(b.stages) and doc["end_tag"] != b.stages[k + 1].doc["start_tag"]:
            self._fail(f"{tag}: the end tag is not the next stage's start tag")

    # -------------------------------------------------------------- report
    def summary(self) -> dict:
        return {
            "bundle": self.b.name,
            "profile": self.b.profile,
            "stages": self.b.blocks,
            "run_binding_reproduced": self.run_binding_ok,
            "positions_checked": self.checkpoints,
            "challenges_checked": self.challenges,
            "segment_position_tags": self.position_tags,
            "final_counter": self.final_counter,
            "not_rederived": self.not_rederived,
            "failures": self.failures,
            "ok": not self.failures,
        }
