#!/usr/bin/env python3
"""[gate round 22, item 4] The C-R1 / C-R2 hash-input census of a classifier run, MEASURED on a capture.
NOT a privacy result.

    python3 hash_census.py <classifier capture dir> <out.json>

Conditions (docs/zkmatrix-poc/ZK60_HASH_LAYER_AND_FS_LIFT_RUN.md §7.2, carried by D33 / D36):
  C-R1  no input to the UNKEYED BLAKE3 function F_U on an accepted run's path is 40 bytes (the prover generator's
        refill input length, `rng.rs`), so no query an adversary can build reaches the randomness stream;
  C-R2  no transcript constructor input has the squeeze length 47 (constructor = "hashline-v1/" || domain, i.e.
        12 + |domain|; squeeze = state(32) || "squeeze"(7) || counter(8));
  W-2   (stage 25's census, as D36 §3 step 5 reads it) the constructor input length equals the length of no other
        input of the transcript function F_T in the run, and is not one byte from any.

What is MEASURED here: the frozen v23 classifier replay (`ClassRunReplay`, which re-derives every challenge of
the run from the capture's public data) is run with the transcript classes and the blake3 constructor wrapped:
every F_T input (constructor, absorb, squeeze) and every UNKEYED blake3 input the gate's own recomputations make
(the run's public digests the gate rebuilds) is recorded BY LENGTH ONLY (no value is kept or printed).  The Rust
F_U call sites of the classifier path are a separate READ table in the round's summary (they are the prover's /
verifier's; the gate's recomputation covers the ones it re-derives).
"""

import collections
import hashlib
import json
import os
import sys
import time

sys.dont_write_bytecode = True
TOOLS = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/frozen_v23/scripts"
sys.path.insert(0, TOOLS)

import blake3 as _blake3_mod  # noqa: E402

FU = collections.Counter()           # unkeyed blake3 input lengths (gate-side recomputations)
FT = {"constructor": collections.Counter(), "absorb": collections.Counter(), "squeeze": collections.Counter()}
FT_KEYED = {"keyed": 0, "unkeyed": 0}

_orig_ctor = _blake3_mod.blake3


class _Counting:
    """a blake3 hasher that remembers its input length; unkeyed ones are counted at digest time"""

    def __init__(self, *a, **kw):
        self._keyed = bool(kw.get("key")) or bool(kw.get("derive_key_context"))
        self._h = _orig_ctor(*a, **kw)
        self._n = len(a[0]) if a and isinstance(a[0], (bytes, bytearray, memoryview)) else 0

    def update(self, data):
        self._n += len(data)
        self._h.update(data)
        return self

    def digest(self, *a, **kw):
        if not self._keyed:
            FU[self._n] += 1
        return self._h.digest(*a, **kw)

    def hexdigest(self, *a, **kw):
        if not self._keyed:
            FU[self._n] += 1
        return self._h.hexdigest(*a, **kw)

    def copy(self):
        c = _Counting.__new__(_Counting)
        c._keyed, c._h, c._n = self._keyed, self._h.copy(), self._n
        return c


_blake3_mod.blake3 = _Counting

import zk60_native_jv_field as F  # noqa: E402
import zk60_native_rg_hashrule as HR  # noqa: E402
import zk60_native_rg_classgate as CG  # noqa: E402


def wrap_transcripts():
    for cls, keyed in ((F.Transcript, False), (HR.KeyedTranscript, True)):
        init, absorb, squeeze = cls.__init__, cls.absorb, cls._squeeze

        def _init(self, *a, _init=init, _keyed=keyed, **kw):
            domain = kw.get("domain")
            if domain is None:
                pos = 1 if _keyed else 0
                domain = a[pos] if len(a) > pos else None
            state = kw.get("state")
            if state is None and domain is not None:
                FT["constructor"][12 + len(domain)] += 1
            _init(self, *a, **kw)

        def _absorb(self, label, data, _absorb=absorb, _keyed=keyed):
            FT["absorb"][32 + 8 + len(label) + 8 + len(data)] += 1
            FT_KEYED["keyed" if _keyed else "unkeyed"] += 1
            return _absorb(self, label, data)

        def _squeeze(self, _squeeze=squeeze, _keyed=keyed):
            FT["squeeze"][32 + 7 + 8] += 1
            FT_KEYED["keyed" if _keyed else "unkeyed"] += 1
            return _squeeze(self)

        cls.__init__, cls.absorb, cls._squeeze = _init, _absorb, _squeeze


def lazy_store():
    """[--lazy-store] resolve array references WITHOUT re-hashing them or scanning their words (so a values
    capture's 2.25 GB store is not made resident: O20-1).  Integrity of these bytes is established elsewhere:
    gate round 20 checked every reference's SHA-256 on the same bundle, and round 21 re-hashed the whole store equal
    to the manifest.  The reference's keys and range are still checked."""
    import numpy as np
    import zk60_native_rg_arrays as AR

    def resolve(self, ref, where):
        elem, n, off, nb = self.check_reference(ref, where)
        a = np.frombuffer(self._buf[off: off + nb], dtype="<u8")
        self.resolutions += 1
        return AR.FpArray(a, ref, where) if elem == "fp" else AR.Fp2Array(a.reshape(n, 2), ref, where)
    AR.ArrayStore.resolve = resolve


def main(cap, out, lazy=False):
    t0 = time.time()
    if lazy:
        lazy_store()
    b = CG.load(cap)                       # (counts the gate's load-time recomputations too)
    fu_after_load = collections.Counter(FU)
    wrap_transcripts()
    rp = CG.ClassRunReplay(b).run()
    s = rp.summary()
    ctor = sorted(FT["constructor"])
    absorb_lens = sorted(FT["absorb"])
    others = set(absorb_lens) | {47}
    w2_hits = {c: sorted(x for x in others if abs(x - c) <= 1) for c in ctor}
    profile = b.run["profile"]
    rec = {"what": "gate round 22 item 4: the C-R1 / C-R2 / W-2 hash-input census of one classifier capture "
                   "[MEASURED by the frozen v23 replay, lengths only]; NOT a privacy result",
           "capture": cap, "profile": profile, "profile_len": len(profile),
           "replay_ok": s.get("ok"), "challenges_checked": s.get("challenges_checked"),
           "positions_checked": s.get("positions_checked"), "run_binding_reproduced": s.get("run_binding_reproduced"),
           "hash_rule": getattr(rp, "rule_name", None),
           "F_T": {"constructor_lengths": {str(k): v for k, v in sorted(FT["constructor"].items())},
                   "absorb_lengths": {str(k): v for k, v in sorted(FT["absorb"].items())},
                   "squeezes": sum(FT["squeeze"].values()), "absorbs": sum(FT["absorb"].values()),
                   "calls_keyed": FT_KEYED["keyed"], "calls_unkeyed": FT_KEYED["unkeyed"]},
           "F_U_gate_recomputations": {"lengths": {str(k): v for k, v in sorted(FU.items())},
                                       "during_load": {str(k): v for k, v in sorted(fu_after_load.items())}},
           "C-R1_no_40_byte_F_U_input_in_the_gate_recomputations": 40 not in FU,
           "C-R2_constructor_not_47": all(c != 47 for c in ctor),
           "W-2_constructor_lengths_and_their_neighbours_within_1": {str(c): v for c, v in w2_hits.items()},
           "W-2_holds": all(not v for v in w2_hits.values()),
           "transcript_query_count_A_measured": sum(FT["absorb"].values()) + sum(FT["squeeze"].values())
                                                + sum(FT["constructor"].values()),
           "lazy_store": lazy, "seconds": round(time.time() - t0, 1)}
    with open(out, "w") as fh:
        json.dump(rec, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print(json.dumps({k: rec[k] for k in ("profile_len", "replay_ok", "challenges_checked", "C-R1_no_40_byte_F_U_input_in_the_gate_recomputations",
                                          "C-R2_constructor_not_47", "W-2_holds", "transcript_query_count_A_measured", "seconds")}))
    print("constructors", rec["F_T"]["constructor_lengths"], "W-2 neighbours", rec["W-2_constructor_lengths_and_their_neighbours_within_1"])


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], lazy="--lazy-store" in sys.argv[3:])
