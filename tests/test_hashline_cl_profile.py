"""[ZK60-CL5] Tests for the profile parser.

No GPU and no proving: the fixtures are literal excerpts of the prover's own
output, so the parser is pinned against the real collector formats rather than
against an idealised one.
"""

import importlib.util
import os
import sys
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_SRC = os.path.join(os.path.dirname(_HERE), "scripts", "hashline_cl_profile.py")
_spec = importlib.util.spec_from_file_location("hashline_cl_profile", _SRC)
prof = importlib.util.module_from_spec(_spec)
sys.modules[_spec.name] = prof
_spec.loader.exec_module(prof)

# A real 12x512 v3 P1 run, trimmed. The phase values sum to the prove clock.
LOG = """  gpu: ON — NVIDIA GeForce RTX 4070 Laptop GPU (sm_89, 36 SMs, 8.6 GB)
  layer 11: prove 0.445 s, 7306036 B
prover phases (summed over layers):
      commit W                      0.772 s
      commit A (zk)                 1.421 s
      mask commit                   0.081 s
      helpers + commit H (zk)       1.334 s
      matmul g/u (zk)               0.171 s
      matmul d (zk)                 0.107 s
      zero-check F (zk)             0.495 s
      zero-check D (zk)             0.106 s
      table zero-check (zk)         0.363 s
      zsum + mask open              0.039 s
      pcs openings (zk)             0.585 s
mask sites (v3; layer 0):
  gpu device-side (summed): h2d 0.326 s (1059 MB) | ntt 1.126 s | hash 0.103 s \
| sumcheck 0.611 s | fold 0.199 s | helpers 0.135 s | d2h 0.000 s (155 MB) | vram peak 3068 MB
PROOF sha256 40eb54795e023c77382a31020aac728485daaae2e1b5ec58c3c82d04f94aac17 (87697008 B) [ZK v3]
PASS-V3 ACCEPT [ZK]: 12 x 512 (d 768 f 2048): witness load+chain 1.74 s | PROVE 5.47 s | VERIFY 0.55 s
HASHLINE_TIMING {"schema":1,"coverage":"ffn-only","privacy":"P1","layers":12,"tokens":512,\
"d":768,"f":2048,"witness_s":1.738586323,"prove_s":5.474589067,"serialize_s":0.115514574,\
"proof_ready_s":7.336610822,"verify_s":0.552182129,"verified":true,"proof_bytes":87697008,\
"serialized":true,"gpu_requested":true,"gpu_enabled":true,"randomness":"deterministic-test"}
"""

FALLBACK_LOG = LOG.replace(
    "  layer 11:",
    "[UPERF3-ZA] gpu zk commit declined (cuMemAlloc(5387 MB): out of memory); CPU path\n  layer 11:",
)


class Parsing(unittest.TestCase):
    def test_reuses_the_prover_timing_json_as_the_clock(self):
        r = prof.attribute(prof.parse_log(LOG))
        self.assertEqual(r["privacy"], "P1")
        self.assertEqual(r["coverage"], "ffn-only")
        self.assertEqual(r["shape"], {"layers": 12, "tokens": 512, "d": 768, "f": 2048})
        self.assertEqual(r["top_level_s"]["prove_s"], 5.474589067)
        self.assertTrue(r["gpu_enabled"])

    def test_every_row_carries_its_context(self):
        r = prof.attribute(prof.parse_log(LOG, command="hashline pass 12 512", exit_code=0))
        for key in ("shape", "privacy", "coverage", "device", "command", "exit_code",
                    "proof_sha256", "proof_bytes", "verdict"):
            self.assertIsNotNone(r[key], f"{key} must be recorded on every row")
        self.assertEqual(r["exit_code"], 0)
        self.assertEqual(r["verdict"], "ACCEPT")
        self.assertIn("RTX 4070", r["device"])

    def test_unknown_exclusive_time_is_reported_not_absorbed(self):
        r = prof.attribute(prof.parse_log(LOG))
        self.assertEqual(len(r["prove_phases_s"]), 11)
        # this real run's phases are exhaustive to sub-millisecond: the
        # residual is 0.589 ms, which is rounding in the printed phase values,
        # not missing work. The assertion is on the MAGNITUDE, not on zero.
        self.assertLess(abs(r["unknown_exclusive_s"]), 0.01)
        self.assertIsNotNone(r["proof_ready_unknown_s"])

    def test_a_missing_phase_shows_up_as_unknown(self):
        """If the phase block stops covering the prove clock, the parser must
        SAY so rather than quietly reporting a smaller total."""
        trimmed = LOG.replace("      commit W                      0.772 s\n", "")
        r = prof.attribute(prof.parse_log(trimmed))
        self.assertAlmostEqual(r["unknown_exclusive_s"], 0.772, places=2)

    def test_device_counters_and_vram_are_parsed(self):
        r = prof.attribute(prof.parse_log(LOG))
        d = r["device_side"]
        self.assertAlmostEqual(d["ntt_s"], 1.126)
        self.assertAlmostEqual(d["h2d_s"], 0.326)
        self.assertEqual(d["h2d_mb"], 1059)
        self.assertEqual(d["vram_peak_mb"], 3068)

    def test_cpu_fallbacks_are_counted(self):
        clean = prof.attribute(prof.parse_log(LOG))
        fell = prof.attribute(prof.parse_log(FALLBACK_LOG))
        self.assertEqual(clean["cpu_fallback_count"], 0)
        self.assertEqual(fell["cpu_fallback_count"], 1)
        self.assertIn("cuMemAlloc", fell["cpu_fallbacks"][0])

    def test_a_log_without_the_timing_line_is_refused(self):
        """The parser reuses the prover's collector; it must not invent a clock
        from the prose lines when the machine-readable one is absent."""
        without = "\n".join(l for l in LOG.splitlines() if not l.startswith("HASHLINE_TIMING"))
        with self.assertRaises(prof.ProfileError) as cm:
            prof.attribute(prof.parse_log(without))
        self.assertIn("refuses to invent a clock", str(cm.exception))


class Ranking(unittest.TestCase):
    def test_top_costs_are_ranked_by_exclusive_time(self):
        r = prof.attribute(prof.parse_log(LOG))
        out = prof.rank([r], top_n=3)
        names = [x["phase"] for x in out["ranked"]]
        self.assertEqual(names[0], "commit A (zk)")      # 1.421
        self.assertEqual(names[1], "helpers + commit H (zk)")  # 1.334
        self.assertEqual(names[2], "commit W")           # 0.772

    def test_bounds_are_independent_and_not_multiplied(self):
        """Each bound removes ONE phase from the same clock. Multiplying them
        is the error that turns a 1.05x into an imaginary 4x."""
        r = prof.attribute(prof.parse_log(LOG))
        out = prof.rank([r], top_n=3)
        ready = out["proof_ready_s"]
        for item in out["ranked"]:
            self.assertAlmostEqual(
                item["bounded_speedup_if_removed_entirely"],
                ready / (ready - item["exclusive_s"]), places=9)
            self.assertIn("upper bound", item["note"])
        self.assertIn("Do NOT multiply", out["amdahl_warning"])

    def test_shares_are_of_proof_ready_not_of_prove(self):
        """Shares must be against the user-visible clock, so a phase cannot be
        made to look bigger by quoting it against a narrower denominator."""
        r = prof.attribute(prof.parse_log(LOG))
        out = prof.rank([r], top_n=1)
        top = out["ranked"][0]
        self.assertAlmostEqual(top["share_of_proof_ready"],
                               top["exclusive_s"] / r["proof_ready_s"], places=9)
        self.assertLess(top["share_of_proof_ready"], top["exclusive_s"] / r["top_level_s"]["prove_s"])


if __name__ == "__main__":
    unittest.main()
