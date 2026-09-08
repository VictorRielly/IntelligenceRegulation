"""[ZK60-CL5] Tests for the profile parser.

No GPU and no proving: the fixtures are literal excerpts of the prover's own
output, so the parser is pinned against the real collector formats rather than
against an idealised one.

Round 7 (Codex review, 2026-09-06): the review reproduced two holes in the
earlier ten tests — an `exit_code=1` row was ranked, and a phase larger than
the proof-ready clock produced a negative bound (-7.34575353). The `Gate`,
`Cache` and `Cli` classes below pin the refusals; the original ten are kept.
The shared fixture now ends with the runner's `exit 0` line, exactly as the
archived results/cl5_sample_p1cold.log does, because exit evidence is now
required before a row may be ranked.
"""

import contextlib
import importlib.util
import io
import json
import os
import sys
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_SRC = os.path.join(os.path.dirname(_HERE), "scripts", "hashline_cl_profile.py")
_SAMPLE = os.path.join(os.path.dirname(_HERE), "results", "cl5_sample_p1cold.log")
_spec = importlib.util.spec_from_file_location("hashline_cl_profile", _SRC)
prof = importlib.util.module_from_spec(_spec)
sys.modules[_spec.name] = prof
_spec.loader.exec_module(prof)

# A real 12x512 v3 P1 run, trimmed. The phase values sum to the prove clock.
# The final `exit 0` is the matrix runner's own appended line (round 7).
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
exit 0
"""

FALLBACK_LOG = LOG.replace(
    "  layer 11:",
    "[UPERF3-ZA] gpu zk commit declined (cuMemAlloc(5387 MB): out of memory); CPU path\n  layer 11:",
)

# src/wcache.rs with HL_WCACHE_VERBOSE=1, one line per layer, verbatim format
# (stderr, merged into the log by the runner's 2>&1).
WC_MISS = ("[UPERF3-AC] wcache MISS -> wrote /sp/wcache-cold/v3-l{l:02d}-1a2b3c.wc "
           "(4.2 MB, commit 0.087 s, write 0.002 s)\n")
WC_HIT = ("[UPERF3-AC] wcache HIT /sp/wcache-cold/v3-l{l:02d}-1a2b3c.wc "
          "(rows 288, 4.2 MB, load+verify 0.008 s, re-encode 0.088 s)\n")
CMD_WC = "HL_GPU=1 HL_WCACHE_VERBOSE=1 hashline pass 12 512 --threads 8 --zk --seed 1 --profile v3 --wcache /sp/wcache-cold"
CMD_NOWC = "HL_GPU=1 HL_WCACHE_VERBOSE=1 hashline pass 12 512 --threads 8 --zk --seed 1 --profile v3"


def _with_cache_lines(kind: str, n: int = 12) -> str:
    lines = "".join(kind.format(l=l) for l in range(n))
    return LOG.replace("  layer 11:", lines + "  layer 11:")


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
                    "proof_sha256", "proof_bytes", "verdict", "cache_state"):
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


class Gate(unittest.TestCase):
    """[round 7] Eligibility: a diagnostic row is retained and marked; it is
    never ranked. Each test is one of the review's missing preconditions."""

    def test_the_clean_fixture_is_eligible(self):
        r = prof.attribute(prof.parse_log(LOG))
        self.assertTrue(r["eligible"], r["ineligible_reasons"])
        self.assertEqual(r["ineligible_reasons"], [])
        self.assertEqual(r["exit_code_source"], "log")

    def test_exit_code_1_row_is_retained_but_never_ranked(self):
        """The review's first control: an `exit_code=1` row received a ranked
        speedup table. It must be kept as a diagnostic and refused by rank()."""
        r = prof.attribute(prof.parse_log(LOG.replace("exit 0\n", "exit 1\n")))
        self.assertFalse(r["eligible"])
        self.assertTrue(any("exit code 1" in x for x in r["ineligible_reasons"]), r["ineligible_reasons"])
        self.assertEqual(len(r["prove_phases_s"]), 11)      # retained, not dropped
        with self.assertRaises(prof.ProfileError) as cm:
            prof.rank([r])
        self.assertIn("not eligible evidence", str(cm.exception))
        self.assertIn("exit code 1", str(cm.exception))
        # the same via the external argument, on a log with no exit line
        bare = LOG.replace("exit 0\n", "")
        r2 = prof.attribute(prof.parse_log(bare, exit_code=1))
        self.assertFalse(r2["eligible"])
        with self.assertRaises(prof.ProfileError):
            prof.rank([r2])

    def test_missing_exit_code_is_ineligible(self):
        bare = LOG.replace("exit 0\n", "")
        r = prof.attribute(prof.parse_log(bare))
        self.assertFalse(r["eligible"])
        self.assertTrue(any("exit code unknown" in x for x in r["ineligible_reasons"]), r["ineligible_reasons"])
        with self.assertRaises(prof.ProfileError):
            prof.rank([r])

    def test_contradictory_exit_code_is_ineligible(self):
        """The log says exit 0, the caller says 1: neither source silently wins."""
        r = prof.attribute(prof.parse_log(LOG, exit_code=1))
        self.assertFalse(r["eligible"])
        self.assertTrue(any("given as 1 but the log records exit 0" in x for x in r["ineligible_reasons"]),
                        r["ineligible_reasons"])

    def test_a_phase_larger_than_proof_ready_is_refused_not_negative(self):
        """The review's second control: a phase of proof_ready_s + 1 produced
        the bound -7.34575353. Two layers now refuse it: the gate on the way
        in, and rank() itself on a row whose flag was forged to eligible."""
        r = prof.attribute(prof.parse_log(LOG))
        ready = r["proof_ready_s"]
        # (a) in the log: the phase is refused at the gate and by rank()
        too_big = LOG.replace("      commit A (zk)                 1.421 s",
                              f"      commit A (zk)                 {ready + 1.0:.3f} s")
        bad = prof.attribute(prof.parse_log(too_big))
        self.assertFalse(bad["eligible"])
        self.assertTrue(any("not smaller than the proof-ready clock" in x for x in bad["ineligible_reasons"]),
                        bad["ineligible_reasons"])
        with self.assertRaises(prof.ProfileError):
            prof.rank([bad])
        # (b) forged: eligible flag left true, phase edited after attribution
        forged = dict(r)
        forged["prove_phases_s"] = dict(r["prove_phases_s"])
        forged["prove_phases_s"]["commit A (zk)"] = ready + 1.0
        with self.assertRaises(prof.ProfileError) as cm:
            prof.rank([forged])
        msg = str(cm.exception)
        self.assertIn("commit A (zk)", msg)
        self.assertIn("negative", msg)
        self.assertNotIn("-7.3", msg)   # no negative bound is ever printed
        # (c) exactly equal: the bound would be infinite, also refused
        forged["prove_phases_s"]["commit A (zk)"] = ready
        with self.assertRaises(prof.ProfileError) as cm:
            prof.rank([forged])
        self.assertIn("infinite", str(cm.exception))

    def test_a_phase_larger_than_prove_but_inside_proof_ready_is_ineligible(self):
        """Smaller than the proof-ready clock, but bigger than the prove clock
        it sits inside: still impossible, still refused (with the residual
        tolerance explained on the row)."""
        r = prof.attribute(prof.parse_log(LOG))
        prove = r["top_level_s"]["prove_s"]
        too_big = LOG.replace("      commit A (zk)                 1.421 s",
                              f"      commit A (zk)                 {prove + 0.5:.3f} s")
        bad = prof.attribute(prof.parse_log(too_big))
        self.assertFalse(bad["eligible"])
        self.assertTrue(any("exceeds the prove clock" in x for x in bad["ineligible_reasons"]),
                        bad["ineligible_reasons"])
        self.assertTrue(any("phases sum to" in x for x in bad["ineligible_reasons"]))
        self.assertAlmostEqual(bad["tolerance_s"], 0.011)   # 11 phases x 1 ms

    def test_non_finite_values_are_refused_at_parse(self):
        for literal in ("NaN", "Infinity", "-Infinity", "1e999"):
            with self.subTest(literal=literal):
                bad = LOG.replace('"prove_s":5.474589067', f'"prove_s":{literal}')
                with self.assertRaises(prof.ProfileError) as cm:
                    prof.parse_log(bad)
                self.assertIn("non-finite", str(cm.exception))
        # a phase line printed as NaN/inf (Rust's {:.3} of a NaN f64 prints "NaN")
        for literal in ("NaN", "inf"):
            with self.subTest(phase=literal):
                bad = LOG.replace("      commit A (zk)                 1.421 s",
                                  f"      commit A (zk)                 {literal} s")
                with self.assertRaises(prof.ProfileError) as cm:
                    prof.parse_log(bad)
                self.assertIn("commit A (zk)", str(cm.exception))
        # and a broken JSON blob is a refusal, not a crash
        with self.assertRaises(prof.ProfileError) as cm:
            prof.parse_log(LOG.replace('"prove_s":5.474589067', '"prove_s":'))
        self.assertIn("not parseable JSON", str(cm.exception))

    def test_negative_clock_is_ineligible(self):
        bad = LOG.replace('"witness_s":1.738586323', '"witness_s":-1.738586323')
        r = prof.attribute(prof.parse_log(bad))
        self.assertFalse(r["eligible"])
        self.assertTrue(any("witness_s is negative" in x for x in r["ineligible_reasons"]), r["ineligible_reasons"])

    def test_contradictory_proof_bytes_is_ineligible(self):
        """The PROOF line and HASHLINE_TIMING must agree on the proof length."""
        bad = LOG.replace("(87697008 B) [ZK v3]", "(87697009 B) [ZK v3]")
        r = prof.attribute(prof.parse_log(bad))
        self.assertFalse(r["eligible"])
        self.assertTrue(any("87697009" in x and "87697008" in x for x in r["ineligible_reasons"]),
                        r["ineligible_reasons"])
        # and a PASS line that carries the proof size must agree too
        bad2 = LOG.replace("| VERIFY 0.55 s", "| VERIFY 0.55 s | proof 1 B (0.0 MB) | wall 7.8 s")
        r2 = prof.attribute(prof.parse_log(bad2))
        self.assertFalse(r2["eligible"])
        self.assertTrue(any("PASS line says proof 1 B" in x for x in r2["ineligible_reasons"]))
        # missing PROOF line altogether
        r3 = prof.attribute(prof.parse_log("\n".join(l for l in LOG.splitlines() if not l.startswith("PROOF "))))
        self.assertFalse(r3["eligible"])

    def test_verified_false_or_reject_is_ineligible(self):
        r = prof.attribute(prof.parse_log(LOG.replace('"verified":true', '"verified":false')))
        self.assertFalse(r["eligible"])
        self.assertTrue(any("verified is False" in x for x in r["ineligible_reasons"]), r["ineligible_reasons"])
        r = prof.attribute(prof.parse_log(LOG.replace('"serialized":true', '"serialized":false')))
        self.assertFalse(r["eligible"])
        r = prof.attribute(prof.parse_log(LOG.replace("PASS-V3 ACCEPT [ZK]", "PASS-V3 REJECT [ZK]")))
        self.assertFalse(r["eligible"])
        self.assertTrue(any("REJECT" in x for x in r["ineligible_reasons"]))
        r = prof.attribute(prof.parse_log("\n".join(l for l in LOG.splitlines() if not l.startswith("PASS-"))))
        self.assertFalse(r["eligible"])
        self.assertTrue(any("no PASS" in x for x in r["ineligible_reasons"]))

    def test_gpu_contradictions_are_ineligible(self):
        """A GPU row must be a GPU row all the way through: requested, enabled,
        and the `gpu: ON` line present. Any two of those disagreeing is a refusal."""
        r = prof.attribute(prof.parse_log(LOG.replace('"gpu_enabled":true', '"gpu_enabled":false')))
        self.assertFalse(r["eligible"])
        self.assertTrue(any("gpu requested but" in x for x in r["ineligible_reasons"]), r["ineligible_reasons"])
        off = LOG.replace("  gpu: ON — NVIDIA GeForce RTX 4070 Laptop GPU (sm_89, 36 SMs, 8.6 GB)",
                          "  gpu: off (HL_GPU unset; built with gpu-cuda)")
        r = prof.attribute(prof.parse_log(off))
        self.assertFalse(r["eligible"])
        self.assertTrue(any("gpu: off" in x for x in r["ineligible_reasons"]), r["ineligible_reasons"])
        r = prof.attribute(prof.parse_log("\n".join(l for l in LOG.splitlines() if not l.startswith("  gpu: ON"))))
        self.assertFalse(r["eligible"])
        self.assertTrue(any("no `gpu: ON` line" in x for x in r["ineligible_reasons"]), r["ineligible_reasons"])
        # a pure CPU row (nothing claims a GPU) is eligible as a CPU row
        cpu = off.replace('"gpu_requested":true,"gpu_enabled":true', '"gpu_requested":false,"gpu_enabled":false')
        r = prof.attribute(prof.parse_log(cpu))
        self.assertTrue(r["eligible"], r["ineligible_reasons"])
        self.assertFalse(r["gpu_enabled"])

    def test_the_command_is_read_from_the_log_and_checked(self):
        logged = "CMD: " + CMD_NOWC + "\n" + LOG
        r = prof.attribute(prof.parse_log(logged))
        self.assertEqual(r["command"], CMD_NOWC)
        self.assertEqual(r["command_source"], "log")
        self.assertTrue(r["eligible"], r["ineligible_reasons"])
        r = prof.attribute(prof.parse_log(logged, command="something else"))
        self.assertFalse(r["eligible"])
        self.assertTrue(any("the log records CMD" in x for x in r["ineligible_reasons"]), r["ineligible_reasons"])

    def test_the_archived_sample_parses_as_eligible(self):
        """results/cl5_sample_p1cold.log: a real p1cold rep 1 from the 2026-09-04
        matrix, with the runner's `exit 0` line. It was recorded WITHOUT
        HL_WCACHE_VERBOSE, and the ZK pass prints no wcache summary, so its
        cache state is honestly `unknown` (the command says --wcache; the log
        cannot say whether it hit). Eligibility does not depend on that."""
        with open(_SAMPLE, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
        r = prof.attribute(prof.parse_log(text, command=CMD_WC))
        self.assertTrue(r["eligible"], r["ineligible_reasons"])
        self.assertEqual(r["exit_code"], 0)
        self.assertEqual(r["exit_code_source"], "log")
        self.assertEqual(r["privacy"], "P1")
        self.assertEqual(r["proof_sha256"], "40eb54795e023c77382a31020aac728485daaae2e1b5ec58c3c82d04f94aac17")
        self.assertEqual(r["proof_bytes"], 87697008)
        self.assertEqual(r["cache_state"], "unknown")
        self.assertTrue(any("HL_WCACHE_VERBOSE unset" in n for n in r["notes"]))
        self.assertEqual(r["cpu_fallback_count"], 0)
        out = prof.rank([r], top_n=3)
        self.assertEqual(out["ranked"][0]["phase"], "commit A (zk)")
        self.assertAlmostEqual(out["proof_ready_s"], 7.345753530)
        for item in out["ranked"]:
            self.assertGreater(item["bounded_speedup_if_removed_entirely"], 1.0)


class Cache(unittest.TestCase):
    """[round 7] Cache state is read from the log itself, not accepted on trust."""

    def test_miss_lines_make_a_cold_row(self):
        r = prof.attribute(prof.parse_log(_with_cache_lines(WC_MISS), command=CMD_WC))
        self.assertEqual(r["cache_state"], "cold")
        self.assertEqual((r["wcache"]["hits"], r["wcache"]["misses"]), (0, 12))
        self.assertEqual(r["wcache"]["entries"][0]["kind"], "MISS")
        self.assertAlmostEqual(r["wcache"]["entries"][0]["commit_s"], 0.087)
        self.assertTrue(r["eligible"], r["ineligible_reasons"])

    def test_hit_lines_make_a_warm_row(self):
        r = prof.attribute(prof.parse_log(_with_cache_lines(WC_HIT), command=CMD_WC))
        self.assertEqual(r["cache_state"], "warm")
        self.assertEqual((r["wcache"]["hits"], r["wcache"]["misses"]), (12, 0))
        e = r["wcache"]["entries"][0]
        self.assertEqual(e["rows"], 288)
        self.assertAlmostEqual(e["load_verify_s"], 0.008)
        self.assertAlmostEqual(e["reencode_s"], 0.088)    # a HIT still re-encodes
        self.assertTrue(r["eligible"], r["ineligible_reasons"])

    def test_mixed_hits_and_misses_are_reported_as_mixed(self):
        text = LOG.replace("  layer 11:", WC_MISS.format(l=0) + WC_HIT.format(l=1) + "  layer 11:")
        r = prof.attribute(prof.parse_log(text, command=CMD_WC))
        self.assertEqual(r["cache_state"], "mixed")

    def test_no_wcache_flag_and_no_lines_is_none(self):
        r = prof.attribute(prof.parse_log(LOG, command=CMD_NOWC))
        self.assertEqual(r["cache_state"], "none")
        self.assertTrue(r["eligible"])

    def test_wcache_flag_without_verbose_lines_is_unknown(self):
        r = prof.attribute(prof.parse_log(LOG, command=CMD_WC))
        self.assertEqual(r["cache_state"], "unknown")
        self.assertTrue(r["eligible"])         # unknown cache state is a note, not a refusal
        self.assertTrue(any("HL_WCACHE_VERBOSE unset" in n for n in r["notes"]))

    def test_no_command_at_all_is_unknown(self):
        r = prof.attribute(prof.parse_log(LOG))
        self.assertEqual(r["cache_state"], "unknown")
        self.assertTrue(any("command unknown" in n for n in r["notes"]))

    def test_cache_lines_without_the_flag_contradict_the_command(self):
        r = prof.attribute(prof.parse_log(_with_cache_lines(WC_HIT), command=CMD_NOWC))
        self.assertFalse(r["eligible"])
        self.assertTrue(any("no --wcache" in x for x in r["ineligible_reasons"]), r["ineligible_reasons"])

    def test_the_driver_summary_line_is_read_and_cross_checked(self):
        """pass_v3 (P0) prints `wcache DIR: hits N | misses N | ...`; the ZK pass
        does not. When present it is used alone, or checked against the lines."""
        summary = "  wcache /sp/wcache-cold: hits 12 | misses 0 | rejected 0 | read 50.4 MB | wrote 0.0 MB | key 0.001 s | load+verify 0.096 s | re-encode 1.056 s | commit(miss) 0.000 s | save 0.000 s\n"
        r = prof.attribute(prof.parse_log(LOG.replace("PROOF sha256", summary + "PROOF sha256"), command=CMD_WC))
        self.assertEqual(r["cache_state"], "warm")
        self.assertEqual(r["wcache"]["summary"]["hits"], 12)
        self.assertTrue(r["eligible"], r["ineligible_reasons"])
        both = _with_cache_lines(WC_MISS).replace("PROOF sha256", summary + "PROOF sha256")
        r = prof.attribute(prof.parse_log(both, command=CMD_WC))
        self.assertFalse(r["eligible"])
        self.assertTrue(any("wcache summary says" in x for x in r["ineligible_reasons"]), r["ineligible_reasons"])

    def test_p3_refusal_of_the_cache_is_labelled(self):
        text = "REFUSED: --wcache with --p3.\n" + LOG.replace("exit 0", "exit 1")
        r = prof.attribute(prof.parse_log(text, command=CMD_WC + " --p3"))
        self.assertEqual(r["cache_state"], "refused")
        self.assertFalse(r["eligible"])


class Cli(unittest.TestCase):
    """[round 7] The command line retains diagnostic rows, marks them, and
    ranks only eligible ones; with none eligible it refuses (exit 2)."""

    def _run(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        old = sys.argv
        sys.argv = ["hashline_cl_profile.py", *argv]
        try:
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                rc = prof.main()
        finally:
            sys.argv = old
        return rc, out.getvalue(), err.getvalue()

    def test_diagnostic_rows_are_retained_marked_and_excluded_from_ranking(self):
        with tempfile.TemporaryDirectory() as d:
            good = os.path.join(d, "good.log")
            bad = os.path.join(d, "bad.log")
            with open(good, "w") as fh:
                fh.write("CMD: " + CMD_NOWC + "\n" + LOG)
            with open(bad, "w") as fh:
                fh.write("CMD: " + CMD_NOWC + "\n" + LOG.replace("exit 0\n", "exit 1\n"))
            rc, out, err = self._run(bad, good, "--rank")
            self.assertEqual(rc, 0, err)
            doc = json.loads(out)
            self.assertEqual(doc["schema"], 2)
            self.assertEqual([r["eligible"] for r in doc["rows"]], [False, True])
            self.assertEqual(doc["diagnostic_rows"], 1)
            self.assertEqual(doc["eligible_rows"], 1)
            self.assertEqual(doc["ranking"]["ranked_row"]["command"], CMD_NOWC)
            self.assertEqual([x["log"] for x in doc["ranking"]["excluded_diagnostic_rows"]], [bad])
            self.assertIn("DIAGNOSTIC (not evidence)", err)
            self.assertIn("exit code 1", err)
            rc, out, err = self._run(bad, "--rank")
            self.assertEqual(rc, 2)
            self.assertIn("no eligible row to rank", err)
            self.assertEqual(out, "")

    def test_a_non_finite_log_is_refused_on_the_command_line(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "nan.log")
            with open(p, "w") as fh:
                fh.write(LOG.replace('"prove_s":5.474589067', '"prove_s":NaN'))
            rc, out, err = self._run(p)
            self.assertEqual(rc, 2)
            self.assertIn("REFUSED", err)
            self.assertIn("non-finite", err)


if __name__ == "__main__":
    unittest.main()
