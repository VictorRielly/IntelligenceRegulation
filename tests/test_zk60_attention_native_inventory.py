"""Tests for scripts/zk60_attention_native_inventory.py.

Three layers:
  1. parser unit tests on small synthetic Rust snippets (no repo file read);
  2. the count cross-checks of the real `hashline/src/private_attention` against the numbers
     ZK60_PRIVATE_ATTENTION_NATIVE.md sections 3 and 5 state;
  3. one end-to-end run that writes the records and checks the two tools' verdicts.

Run:
    python3 -m unittest discover -s tests -p 'test_zk60_attention_native_inventory.py' -v
"""
import importlib.util
import json
import os
import shutil
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "scripts", "zk60_attention_native_inventory.py")

_spec = importlib.util.spec_from_file_location("zk60_attention_native_inventory", SCRIPT)
NI = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(NI)

MODULE = os.path.join(ROOT, "hashline", "src", "private_attention")
LAYOUT_RS = os.path.join(MODULE, "layout.rs")
ARGUMENT_RS = os.path.join(MODULE, "argument.rs")


# ---------------------------------------------------------------------------
# 1. parser unit tests on synthetic snippets
# ---------------------------------------------------------------------------

SYNTH_LAYOUT = """
//! a synthetic two-slot layout
use crate::field::Fp2;

pub(crate) const T: usize = 4;
pub(crate) const LOG_N: usize = 8;
pub(crate) const N: usize = 1 << LOG_N;
pub(crate) const N_LIMBS: usize = 2;

pub(crate) enum Dom { Small, Wide, Tab }

impl Dom {
    pub(crate) fn log(self) -> usize {
        match self {
            Dom::Small => 5,
            Dom::Wide => 9,
            Dom::Tab => 8,
        }
    }
}

pub(crate) const A_P0: usize = 0;
pub(crate) const A_P1: usize = 1;
pub(crate) const A_P2: usize = 2;   // ..= A_P3
pub(crate) const A_P3: usize = 3;
pub(crate) const A_MU: usize = 4;
pub(crate) const N_A: usize = 5;

pub(crate) fn a_dom(plane: usize) -> Dom {
    match plane {
        A_P0 | A_P1 => Dom::Small,
        A_P2..=A_P3 => Dom::Wide,
        _ => Dom::Tab,
    }
}

pub(crate) const H_H0: usize = 0;   // ..= 3
pub(crate) const H_G: usize = 4;
pub(crate) const H_U: usize = 5;
pub(crate) const N_H: usize = 6;

pub(crate) fn h_dom(plane: usize) -> Dom {
    match plane {
        H_H0..=3 => Dom::Wide,
        _ => Dom::Tab,
    }
}

fn byte(p: usize) -> Lk { Lk { terms: vec![(p, 1)], cst: 0 } }
fn scaled(p: usize, k: i64) -> Lk { Lk { terms: vec![(p, k)], cst: 0 } }
fn sym(p: usize) -> [Lk; 2] { [Lk { terms: vec![(p, 1)], cst: 127 }, Lk { terms: vec![(p, -1)], cst: 127 }] }

pub(crate) fn lookups(dom: Dom) -> Vec<Lk> {
    let mut v = Vec::new();
    match dom {
        Dom::Small => v.push(byte(A_P0)),
        Dom::Wide => {
            v.extend([byte(A_P2), byte(A_P3)]);
            v.extend(sym(A_P2));
            v.extend((0..3).map(|k| byte(A_P2 + k)));
            v.push(scaled(A_P3, 2));
        }
        Dom::Tab => {}
    }
    v
}

pub(crate) fn helpers(dom: Dom) -> (usize, usize) {
    match dom {
        Dom::Small => (H_H0, 1),
        Dom::Wide => (H_H0, 4),
        _ => (0, 0),
    }
}

pub(crate) const LOOKUP_DOMS: [Dom; 2] = [Dom::Small, Dom::Wide];

pub(crate) const N_SLOTS: usize = 2;
pub(crate) const SC_A: usize = 0;
pub(crate) const SC_B: usize = 1;

pub(crate) const SLOT_NAMES: [&str; N_SLOTS] = [
    "00 first slot (private)",
    "01 second slot (hosts 00)",
];

pub(crate) const SLOTS: [(usize, usize, usize); N_SLOTS] = [
    (4, 1, 2),
    (6, 2, 3),
];

pub(crate) const SLOT_KINDS: [SlotKind; N_SLOTS] = [
    SlotKind::Private,
    SlotKind::Host,
];

pub(crate) const HOSTS: [(usize, &[usize]); 1] = [
    (SC_B, &[SC_A]),
];

pub(crate) const A_SITES: [usize; N_SLOTS] = [1, 5];
pub(crate) const H_SITES: [usize; N_SLOTS] = [0, 4];
pub(crate) const A_GROUPS: usize = 4;
pub(crate) const H_GROUPS: usize = 1;
pub(crate) const N_FUNCTIONALS: usize = 4;
pub(crate) const M_ROWS: usize = 2 * N_SLOTS + 4;
"""

SYNTH_ARGUMENT = """
pub(crate) fn define(slot: usize, ctx: &Ctx, pts: &mut Points, tr: &mut Transcript) -> Result<SlotDef, String> {
    let lay = ctx.lay;
    let mut b = B::new(lay, slot);
    match slot {
        SC_A => {
            pts.r_x = tr.challenge_fp2_vec(5);
            b.eq(&pts.r_x, 0);
            b.a(A_P2)?;
            b.finish(Box::new(|v: &[Fp2]| v[0].mul(v[1])), vec![])
        }
        SC_B => {
            let tau = tr.challenge_fp2_vec(9);
            let nu = nonzero(tr.challenge_fp2_vec(1))?[0];
            b.eq(&tau, 0);
            let idx = b.a_range(A_P2, A_P3)?;
            for kk in 0..N_LIMBS {
                b.a_slice(lay.a_off[A_P0] + kk * T, 5, rho(0..5), 0)?;
            }
            let mut cf = rho(0..9);
            cf[6] = Coord::Flip(6);
            let iflip = b.a_at(A_P2, cf, 0)?;
            let h0 = b.h(H_H0)?;
            for j in 1..helpers(Dom::Wide).1 {
                b.h(H_H0 + j)?;
            }
            b.finish(Box::new(|v: &[Fp2]| v[0].mul(v[1])), vec![(SC_A, nu)])
        }
        _ => Err("unknown slot".into()),
    }
}
"""


class TestRustHelpers(unittest.TestCase):
    def test_strip_comments_keeps_lines(self):
        src = "let a = 1; // hello\nlet b = 2;\n"
        self.assertEqual(NI.strip_comments(src), "let a = 1; \nlet b = 2;")

    def test_split_top_respects_depth(self):
        self.assertEqual(NI.split_top("a, f(b, c), [d, e]"), ["a", "f(b, c)", "[d, e]"])
        self.assertEqual(NI.split_top("x; y { z; w }", ";"), ["x", "y { z; w }"])

    def test_brace_block(self):
        inner, after = NI.brace_block("fn f() { a { b } c } tail", 7)
        self.assertEqual(inner.strip(), "a { b } c")
        self.assertEqual("fn f() { a { b } c } tail"[after:], " tail")

    def test_eval_int(self):
        env = {"K": 4, "M": 3}
        self.assertEqual(NI.eval_int("1 << 8", env), 256)
        self.assertEqual(NI.eval_int("K + M", env), 7)
        self.assertEqual(NI.eval_int("K - 1", env), 3)
        self.assertEqual(NI.eval_int("2 * K", env), 8)
        self.assertEqual(NI.eval_int("K / 2", env), 2)
        self.assertEqual(NI.eval_int("(K)", env), 4)
        with self.assertRaises(NI.RustParseError):
            NI.eval_int("mystery_thing", env)

    def test_parse_scalar_consts_and_arrays(self):
        c = NI.parse_scalar_consts(NI.strip_comments(SYNTH_LAYOUT))
        self.assertEqual(c["N"], 256)
        self.assertEqual(c["M_ROWS"], 8)
        self.assertEqual(c["A_P3"], 3)
        self.assertEqual(NI.parse_array(SYNTH_LAYOUT, "A_SITES"), ["1", "5"])
        self.assertEqual(NI.parse_array(SYNTH_LAYOUT, "SLOTS"), ["(4, 1, 2)", "(6, 2, 3)"])

    def test_parse_dom_logs_and_maps(self):
        src = NI.strip_comments(SYNTH_LAYOUT)
        logs = NI.parse_dom_logs(src)
        self.assertEqual(logs, {"Small": 5, "Wide": 9, "Tab": 8})
        consts = NI.parse_scalar_consts(src)
        a = NI.parse_dom_map(src, "a_dom", consts, 5)
        self.assertEqual(a, ["Small", "Small", "Wide", "Wide", "Tab"])
        h = NI.parse_dom_map(src, "h_dom", consts, 6)
        self.assertEqual(h, ["Wide", "Wide", "Wide", "Wide", "Tab", "Tab"])

    def test_parse_lookups_and_helpers(self):
        src = NI.strip_comments(SYNTH_LAYOUT)
        logs = NI.parse_dom_logs(src)
        counts = NI.parse_lookup_counts(src, logs)
        # 2 (array) + 2 (sym) + 3 (map over 0..3) + 1 (push)
        self.assertEqual(counts["Wide"], 8)
        self.assertEqual(counts["Small"], 1)
        self.assertEqual(counts["Tab"], 0)
        self.assertEqual(NI.parse_helpers(src)["Wide"], ("H_H0", 4))

    def test_parse_lookups_refuses_unknown_form(self):
        bad = SYNTH_LAYOUT.replace("v.push(scaled(A_P3, 2));", "v.extend(mystery(A_P3));")
        with self.assertRaises(NI.RustParseError):
            NI.parse_lookup_counts(NI.strip_comments(bad), NI.parse_dom_logs(bad))


class TestSyntheticLayout(unittest.TestCase):
    def setUp(self):
        self.lay = NI.Layout(SYNTH_LAYOUT)

    def test_geometry(self):
        lay = self.lay
        # planes 0, 1 are 32 entries -> 1 row each; 2, 3 are 512 -> 2 rows; 4 is 256 -> 1 row
        self.assertEqual(lay.a_off, [0, 256, 512, 1024, 1536])
        self.assertEqual(lay.a_data_rows, 7)
        self.assertEqual(sum(lay.a_sites), 6)
        self.assertEqual(lay.a_mask_base, 7)
        self.assertEqual(lay.a_prox, 7 + 12)
        self.assertEqual(lay.a_rows, 21)
        # H: planes 0-3 are 512 -> 2 re + 2 im rows each; planes 4, 5 are 256 -> 1 + 1 each
        self.assertEqual(lay.h_data_rows, 20)
        self.assertEqual(lay.h_off[0], (0, 512))
        self.assertEqual(lay.h_u_rows(), [18, 19])
        self.assertEqual(lay.h_rows, 20 + 8 + 2)
        self.assertEqual(lay.a_site_row(1, 0), 9)
        self.assertEqual(lay.h_site_row(1, 1), 22)

    def test_slot_tables(self):
        lay = self.lay
        self.assertEqual(lay.slots, [(4, 1, 2), (6, 2, 3)])
        self.assertEqual(lay.slot_kinds, ["Private", "Host"])
        self.assertEqual(lay.hosts, [(1, [0])])
        self.assertEqual(lay.slot_names[1], "01 second slot (hosts 00)")
        self.assertEqual(lay.slot_const, {"SC_A": 0, "SC_B": 1})


class TestSyntheticDefine(unittest.TestCase):
    def setUp(self):
        self.lay = NI.Layout(SYNTH_LAYOUT)
        self.sites = NI.DefineParser(self.lay, SYNTH_ARGUMENT).parse()

    def test_site_counts_match_the_declaration(self):
        for s in range(self.lay.n_slots):
            a = [x for x in self.sites[s] if x.cm == "A"]
            h = [x for x in self.sites[s] if x.cm == "H"]
            self.assertEqual(len(a), self.lay.a_sites[s], f"slot {s} A")
            self.assertEqual(len(h), self.lay.h_sites[s], f"slot {s} H")

    def test_points_rho_fixed_and_flip(self):
        a0 = self.sites[0][0]
        self.assertEqual(a0.coords, [f"rho_SC_A[{i}]" for i in range(9)])
        flip = [x for x in self.sites[1] if any(c.startswith("1-") for c in x.coords)]
        self.assertEqual(len(flip), 1)
        self.assertEqual(flip[0].coords[6], "1-rho_SC_B[6]")

    def test_loop_sites_get_their_own_offsets(self):
        subs = [x for x in self.sites[1] if x.log == 5]
        self.assertEqual([x.offset for x in subs], [0, 4])   # a_off[A_P0] + kk * T

    def test_site_index_k_is_the_call_order(self):
        a = [x for x in self.sites[1] if x.cm == "A"]
        self.assertEqual([x.k for x in a], [0, 1, 2, 3, 4])
        h = [x for x in self.sites[1] if x.cm == "H"]
        self.assertEqual([x.k for x in h], [0, 1, 2, 3])

    def test_unrecognised_site_call_is_refused(self):
        bad = SYNTH_ARGUMENT.replace("b.a(A_P2)?;", "b.a(some_helper(A_P2, 3))?;")
        with self.assertRaises(NI.RustParseError):
            NI.DefineParser(self.lay, bad).parse()

    def test_missing_site_call_is_refused(self):
        # a call the interpreter cannot reach must not silently disappear
        bad = SYNTH_ARGUMENT.replace("b.a(A_P2)?;", "match ctx.mode { _ => b.a(A_P2)?, };")
        with self.assertRaises(NI.RustParseError):
            NI.DefineParser(self.lay, bad).parse()


class TestStatementSplitter(unittest.TestCase):
    def test_block_statements_are_separated(self):
        block = """
            if slot == SC_A {
                pts.r = tr.challenge_fp2_vec(5);
            }
            let x = match slot { SC_A => (1, 2), _ => (3, 4) };
            let y = if q { (5,) } else { (6,) };
            b.finish(Box::new(poly), vec![])
        """
        stmts = [s.strip() for s in NI.DefineParser._statements(block) if s.strip()]
        self.assertTrue(stmts[0].startswith("if slot == SC_A"))
        self.assertTrue(stmts[0].endswith("}"))
        self.assertTrue(stmts[1].startswith("let x = match slot"))
        self.assertTrue(stmts[2].startswith("let y = if q"))
        self.assertTrue(stmts[-1].startswith("b.finish"))


class TestPcsKeyRule(unittest.TestCase):
    def test_full_row_key_is_the_point_tail(self):
        self.assertEqual(NI.zkey(1024, 9, [f"r{i}" for i in range(9)]),
                         (tuple(f"r{i}" for i in range(1, 9)), 0, 256))

    def test_sub_row_key_carries_the_column_window(self):
        # two 32-entry slices of the SAME row at the same point are DIFFERENT groups
        k0 = NI.zkey(1024, 5, ["a", "b", "c", "d", "e"])
        k1 = NI.zkey(1024 + 32, 5, ["a", "b", "c", "d", "e"])
        self.assertEqual(k0, (("a", "b", "c", "d", "e"), 0, 32))
        self.assertNotEqual(k0, k1)
        # a slice of the NEXT row at c0 = 0 shares the key (row weights differ, columns do not)
        self.assertEqual(NI.zkey(1024 + 256, 5, ["a", "b", "c", "d", "e"]), k0)

    def test_group_sites_is_first_occurrence(self):
        sites = [{"index": 0, "zkey": ("x", 0, 256)}, {"index": 1, "zkey": ("y", 0, 32)},
                 {"index": 2, "zkey": ("x", 0, 256)}]
        g = NI.group_sites(sites)
        self.assertEqual([x["members"] for x in g], [[0, 2], [1]])

    def test_sub_row_tail_preserves_key_equality_and_length(self):
        t0 = NI.sub_row_tail(["a", "b", "c", "d", "e"], 0, 32)
        t1 = NI.sub_row_tail(["a", "b", "c", "d", "e"], 32, 32)
        self.assertEqual(len(t0), 8)
        self.assertEqual(len(t1), 8)
        self.assertNotEqual(t0, t1)
        self.assertEqual(t0, NI.sub_row_tail(["a", "b", "c", "d", "e"], 0, 32))


class TestSingletonExpectation(unittest.TestCase):
    def _sched(self, sites, groups):
        return {"commitments": {"A": {"sites": sites}}, "groups": {"A": groups}}

    def test_constant_row_bits_collapse_symbolic_ones_do_not(self):
        sites = [{"claim_index": i, "site": f"s{i}", "data_row_range": [10, 12], "row_bits": ["x"]} for i in range(3)]
        groups = [{"group": i, "singleton": True, "members": [i]} for i in range(3)]
        # three singletons on one 2-row plane at a symbolic bit: saturates at 2
        self.assertEqual(NI.native_singleton_expectation(self._sched(sites, groups))["expected_disclosed_dim"], 2)
        sites = [{"claim_index": i, "site": f"s{i}", "data_row_range": [4, 5], "row_bits": []} for i in range(7)]
        groups = [{"group": i, "singleton": True, "members": [i]} for i in range(7)]
        # seven singletons all selecting row 4: one functional
        self.assertEqual(NI.native_singleton_expectation(self._sched(sites, groups))["expected_disclosed_dim"], 1)


# ---------------------------------------------------------------------------
# 2. the real module: the count cross-checks against the delivery note
# ---------------------------------------------------------------------------


@unittest.skipUnless(os.path.exists(LAYOUT_RS), "hashline/src/private_attention/layout.rs not present")
class TestNativeLayoutCounts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(LAYOUT_RS) as f:
            cls.lay = NI.Layout(f.read())
        with open(ARGUMENT_RS) as f:
            cls.sites = NI.DefineParser(cls.lay, f.read()).parse()
        with open(os.path.join(MODULE, "protocol.rs")) as f:
            cls.protocol = f.read()
        cls.inv = NI.build_inventory(cls.lay, cls.sites, {}, ROOT, protocol_src=cls.protocol)
        cls.checks = NI.cross_checks(cls.lay, cls.inv)

    def test_every_cross_check_against_the_note_passes(self):
        bad = [(c["name"], c["got"], c["note_says"]) for c in self.checks if not c["pass"]]
        self.assertEqual(bad, [], f"{len(bad)} of {len(self.checks)} cross-checks disagree with the note")

    def test_rows_and_sites(self):
        self.assertEqual((self.lay.a_data_rows, self.lay.a_rows), (154, 306))
        self.assertEqual((self.lay.h_data_rows, self.lay.h_rows), (218, 290))
        self.assertEqual(sum(self.lay.a_sites), 75)
        self.assertEqual(sum(self.lay.h_sites), 35)

    def test_groups_are_derived_not_assumed(self):
        self.assertEqual(self.inv["A1_schedule"]["group_counts"], {"A": 30, "H": 8})
        self.assertEqual(self.lay.consts["A_GROUPS"], 30)
        self.assertEqual(self.lay.consts["H_GROUPS"], 8)

    def test_parsed_site_counts_equal_the_declared_per_slot_counts(self):
        for s in range(self.lay.n_slots):
            a = [x for x in self.sites[s] if x.cm == "A"]
            h = [x for x in self.sites[s] if x.cm == "H"]
            self.assertEqual(len(a), self.lay.a_sites[s], f"slot {s} ({self.lay.slot_name_of[s]}) A sites")
            self.assertEqual(len(h), self.lay.h_sites[s], f"slot {s} ({self.lay.slot_name_of[s]}) H sites")

    def test_m_rows_functionals_and_largest_mask_row(self):
        lens = [(m + e) * d + 2 for m, e, d in self.lay.slots]
        self.assertEqual(max(lens), 50)
        self.assertTrue(all(L + 256 <= 512 for L in lens))
        self.assertEqual(self.lay.consts["M_ROWS"], 40)
        self.assertEqual(self.lay.consts["N_FUNCTIONALS"], 28)

    def test_lookup_totals(self):
        self.assertEqual(NI.lookup_total(self.lay), {"U8": 47104, "exp": 2048})

    def test_sub_row_grouping_splits_the_limb_sites(self):
        sub = [g for g in self.inv["A1_schedule"]["opening_groups"]["A"] if g["len"] < 256]
        self.assertEqual(len(sub), 10)                       # 8 at len 32, 1 at len 32 (D), 1 at len 64
        c0s = sorted(g["c0"] for g in sub if g["len"] == 32)
        self.assertEqual(c0s, [0, 0, 32, 64, 96, 128, 160, 192, 224])

    def test_the_logup_sum_claim_signs_are_parsed_from_protocol_rs(self):
        parsed = NI.parse_logup_sum(self.protocol, self.lay)
        self.assertEqual(parsed["negated_planes"],
                         sorted((self.lay.consts["H_GU8"], self.lay.consts["H_GEXP"])))
        self.assertEqual(parsed["planes"], self.lay.n_h)
        sc = [c for c in self.inv["A1_schedule"]["claims"] if c["sum_claim"]][0]
        neg = [p["plane"] for p in sc["sum_parts"] if p["sign"] == -1]
        self.assertEqual(neg, parsed["negated_planes"])
        self.assertEqual(len(sc["sum_parts"]), self.lay.n_h)

    def test_logup_sum_parse_refuses_a_changed_claim(self):
        bad = self.protocol.replace("value: Fp2::ZERO", "value: Fp2::ONE")
        with self.assertRaises(NI.RustParseError):
            NI.parse_logup_sum(bad, self.lay)
        bad = self.protocol.replace("for p in 0..N_H {", "for p in 0..N_SLOTS {")
        with self.assertRaises(NI.RustParseError):
            NI.parse_logup_sum(bad, self.lay)


# ---------------------------------------------------------------------------
# 3. end to end: both tools re-run, the records written
# ---------------------------------------------------------------------------


@unittest.skipUnless(os.path.exists(LAYOUT_RS), "hashline/src/private_attention/layout.rs not present")
class TestEndToEnd(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp(prefix="zk60-native-rank-cfs-")
        cls.summary = NI.build_all(ROOT, cls.tmp, seed=NI.DEFAULT_SEED, n_values=4)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def _load(self, name):
        with open(os.path.join(self.tmp, name)) as f:
            return json.load(f)

    def test_every_record_is_written(self):
        for name in ("zk60_attention_native_inventory.json", "zk60_attention_native_hosts.json",
                     "zk60_attention_native_pair_schedule.json", "zk60_attention_native_schedule.json",
                     "zk60_attention_native_cfs_slots.json", "zk60_attention_native_summary.json"):
            self.assertTrue(os.path.exists(os.path.join(self.tmp, name)), name)

    def test_no_failures(self):
        self.assertEqual(self.summary["failures"], [])
        self.assertTrue(self.summary["all_pass"])

    def test_rank_verdicts(self):
        r = self._load("zk60_attention_native_pair_schedule.json")["rank_verdicts"]
        self.assertEqual(r["whole_A_per_column"]["disclosed_dim"], 0)
        self.assertEqual(r["whole_A_with_values_n4"]["disclosed_dim"], 0)
        self.assertEqual(r["whole_H_per_column"]["disclosed_dim"], 0)
        for n in (4, 8):
            self.assertEqual(r[f"whole_H_with_values_n{n}"]["disclosed_dim"], 2)
            self.assertTrue(r[f"whole_H_with_values_n{n}"]["residual_is_exactly_the_public_identity"])
        groups = {k: v["disclosed_dim"] for k, v in r.items() if k.startswith("group_")}
        # 30 A groups + the 6 H evaluation groups the tool sees (the SC_ZS group is the tool's
        # own zsum construction, adaptation R-4, so it is not a `group_H_*` entry)
        self.assertEqual(len(groups), 30 + 6)
        self.assertEqual(sorted(set(groups.values())), [0])

    def test_negative_controls_are_all_positive(self):
        nc = self._load("zk60_attention_native_pair_schedule.json")["rank_verdicts"]["negative_controls"]
        self.assertTrue(nc, "no negative controls ran")
        for k, v in nc.items():
            self.assertEqual(v["verdict"], "PASS", f"{k}: {v}")
        self.assertGreater(nc["no_mask_A_per_column"]["disclosed_dim"], 0)
        self.assertEqual(nc["prox_pair_singleton_pair_claim_per_column"]["disclosed_dim"], 0)
        self.assertEqual(nc["single_prox_row_singleton_pair_claim_per_column"]["disclosed_dim"], 1)

    def test_cfs_verdicts(self):
        c = self._load("zk60_attention_native_cfs_slots.json")
        self.assertTrue(c["all_checks_pass"], [x for x in c["checks"] if not x["pass"]])
        self.assertEqual(len(c["slot_table"]), 18)
        self.assertEqual(c["m_layout"]["n_rows"], 40)
        self.assertEqual(c["m_layout"]["n_functionals"], 28)
        self.assertEqual(c["largest_slot"]["len"], 50)
        self.assertLessEqual(c["largest_slot"]["len"] + 256, 512)
        for s, v in c["standalone"].items():
            self.assertEqual(v["rank_map"], v["n_vars"] * v["degree"] + 1, s)
            self.assertEqual(v["dim_consistency_subspace"], v["rank_map"], s)
            self.assertEqual(v["leaked_dim_fp2"], 0, s)
            self.assertEqual(v["kernel_dim_fp2"], 1, s)
        self.assertEqual(len(c["host_groups"]), 5)
        for h, v in c["host_groups"].items():
            k = len(v["hosted"])
            self.assertEqual(v["rank_map"], v["sum_L"] - (k + 1), h)
            self.assertEqual(v["dim_consistency_subspace"], v["rank_map"], h)
            self.assertEqual(v["kernel_dim_fp2"], k + 1, h)
            self.assertEqual(v["leaked_dim_fp2"], 0, h)
            self.assertTrue(v["relabelling"]["pass"], h)
            self.assertTrue(v["f_part_round0"]["consistent"], h)
        for k, v in c["negative_controls"].items():
            if isinstance(v, dict) and "pass" in v:
                self.assertTrue(v["pass"], k)
        self.assertTrue(c["r7_extension_check"]["pass"])

    def test_inventory_is_shaped_for_both_tools(self):
        inv = self._load("zk60_attention_native_inventory.json")
        self.assertIn("A1_schedule", inv)
        self.assertIn("A2_cfs_slots", inv)
        claims = inv["A1_schedule"]["claims"]
        self.assertEqual(len(claims), 111)                   # 75 A + 35 H evaluation + 1 H sum
        for i, c in enumerate(claims):
            self.assertEqual(c["index"], i)
            for k in ("commitment", "site", "group_key", "data_rows", "log_size", "offset",
                      "parts", "role", "section", "sum_claim"):
                self.assertIn(k, c)
            if not c["sum_claim"]:
                self.assertEqual(c["data_rows"], 1 << (c["log_size"] - 8))
                self.assertEqual(c["group_key"], c["point"][c["log_size"] - 8:])
        p1 = inv["A2_cfs_slots"]["P1"]
        self.assertEqual(len(p1), 18)
        for s in p1:
            for k in ("slot", "name", "main_rounds", "ext_rounds", "n_vars", "degree", "cfs_len",
                      "claimed_sum_form"):
                self.assertIn(k, s)
            self.assertEqual(s["n_vars"], s["main_rounds"] + s["ext_rounds"])
            self.assertEqual(s["cfs_len"], s["n_vars"] * s["degree"] + 2)

    def test_schedule_rows_are_the_layouts_rows(self):
        sch = self._load("zk60_attention_native_schedule.json")
        self.assertEqual(sch["A"]["rows_total"], 306)
        self.assertEqual(sch["H"]["rows_total"], 290)
        self.assertEqual(sch["H"]["h_u"]["mask_rows"], [216, 217])
        self.assertEqual(sch["H"]["prox"]["mask_rows"], [288, 289])
        self.assertEqual(sch["A"]["prox"]["mask_rows"], [304, 305])

    def test_summary_records_the_adaptations_and_findings(self):
        s = self._load("zk60_attention_native_summary.json")
        self.assertTrue(s["adaptations"]["rank"])
        self.assertTrue(s["adaptations"]["cfs"])
        self.assertTrue(s["ambiguities"])
        ids = [f["id"] for f in s["findings"]]
        self.assertIn("F-0", ids)
        self.assertIn("F-1", ids)


if __name__ == "__main__":
    unittest.main()
