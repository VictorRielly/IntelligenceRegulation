//! **D63 Lean lane L47 (2026-11-10): the VALUES of the lookup side's public tables, as the production `define` builds
//! them on a REAL W16R2 block receipt, with the public data they are built from, the verifier's slot kinds and its
//! LogUp sum claim** (finding L44-E2: lane L44's export compared the public tables' lengths only). TEST ONLY: a child
//! of the test-only `private_block/w16r2_tests.rs` (declared there by one `#[cfg(test)]` line; the file lives in `src/`,
//! as lanes L10's, L18's and L44's do, so `s25_tests`' `TEST_ONLY_FILES` needs no entry). No prover or verifier source
//! changes; nothing here is reachable from a production build.
//!
//! At the W16R2 development rung (`shape::W16R2_RUNG_H24`), with `w16r2_tests`' seeded block harness (`rung_case`,
//! `prove`, `verify`, `header`), as lane L44's export:
//! 1. proves one block CORE and verifies it with the production `verify_core`;
//! 2. replays `verify_core`'s head (the `A` root, `M`, `beta`, `gamma`, `alpha`, the `H` root) and the slot loop (the
//!    production `define` and `run_slot`, `Side::Verify`, on the real transcript);
//! 3. writes, for the lookup side's slots `SC_LZC` (3), `SC_TAB` (19) and `SC_ZS` (20), every public table `define`
//!    built, numbered in the slot's order of public tables: its length, two polynomial fingerprints
//!    `sum_i v_i rho^i` (`Fp2` arithmetic, at the fixed public points `rho = 7 + 3u` and `rho = 1234567 + 89u`), its
//!    first and last 64 entries, and, in the FULL corpus only, every entry (two base words each);
//! 4. writes the public data those tables are built from: the exp table (`AttentionPublic::exp`, its first 256
//!    entries), the number of ACT groups and each group's scaled ACT table (`AccuracyPublic::scaled_tables`, 4096
//!    words); the verifier's slot kinds (`layout::SLOT_KINDS`, which `run_slot` reads); and the claim
//!    `protocol::logup_sum_claim` that `verify_core`'s `finish_claims` appends to `H`'s claims (every part's offset,
//!    log size, coefficient, point, and the value);
//! 5. writes the FULL record to `$LEAN_L47_CORPUS` (outside the repository) and the record without the full tables to
//!    `$LEAN_L47_CORPUS_SHORT`, for `formal/ZK60Formal/BlockTabExportCheck.lean` (against `Tab.restE` and
//!    `DefW16.logupSumW16`).
//!
//! Every value is public: the fixture's public synthetic data, the transcript's challenges, the verifier's tables.
use super::super::argument::{define, run_slot, Acc, Ctx, Points, Side, Tab};
use super::*;
use std::fmt::Write as _;

fn f2(x: &Fp2) -> String {
    format!("{},{}", x.c0.0, x.c1.0)
}

fn f2s(v: &[Fp2]) -> String {
    if v.is_empty() {
        "-".to_string()
    } else {
        v.iter().map(f2).collect::<Vec<_>>().join(",")
    }
}

fn ints(v: &[i64]) -> String {
    if v.is_empty() {
        "-".to_string()
    } else {
        v.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(",")
    }
}

/// `sum_i v_i rho^i` (Horner from the last entry)
fn fingerprint(v: &[Fp2], rho: Fp2) -> Fp2 {
    v.iter().rev().fold(Fp2::ZERO, |acc, x| acc.mul(rho).add(*x))
}

fn kind_s(k: SlotKind) -> &'static str {
    match k {
        SlotKind::Private => "private",
        SlotKind::Standalone => "standalone",
        SlotKind::Host => "host",
    }
}

/// the two records: every line goes to both, a table's entries to the full one only
#[derive(Default)]
struct Out {
    full: String,
    short: String,
}

impl Out {
    fn both(&mut self, line: String) {
        writeln!(self.short, "{line}").unwrap();
        writeln!(self.full, "{line}").unwrap();
    }
    fn full_only(&mut self, line: String) {
        writeln!(self.full, "{line}").unwrap();
    }
}

/// the slots whose public tables are the lookup side's
const LOOKUP_SLOTS: [usize; 3] = [3, 19, 20];

/// how many entries of each table's head and tail the corpus carries
const ENDS: usize = 64;

/// one block receipt's record: (the full record, the record without the full tables)
fn export(profile: &str) -> (String, String) {
    let (sh, blk, w) = rung_case(profile);
    let core = prove(&sh, &blk, copy(&w)).expect("the honest rung core");
    verify(&sh, &blk, &core).expect("the honest rung core verifies (production verify_core)");
    let lay = Layout::for_shape(&sh).unwrap();
    let rho1 = Fp2::new(Fp::new(7), Fp::new(3));
    let rho2 = Fp2::new(Fp::new(1234567), Fp::new(89));
    let mut out = Out::default();
    out.both(format!("L47 {} {} {}", sh.name, sh.n_slots(), sh.log_cols));
    out.both(format!("RHO {} {}", f2(&rho1), f2(&rho2)));
    // `verify_core`'s head (protocol.rs, as lanes L11's and L44's exports replay it)
    let mut tr = header(&sh, &lay);
    protocol::absorb_root(&mut tr, b"A", &core.a_root, lay.a_rows, sh.log_cols);
    tr.absorb(b"M", &core.mask_root);
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let g_u8 = gamma.mul_base(Fp::new(crate::tables_attn::TAG_U8));
    let g_exp = gamma.mul_base(Fp::new(crate::tables_attn::TAG_EXP));
    let g_act = gamma.mul_base(Fp::new(crate::tables_attn::TAG_ACT));
    protocol::absorb_root(&mut tr, b"H", &core.h_root, lay.h_rows, sh.log_cols);
    let g_dd = gamma.mul_base(Fp::new(TAG_DD));
    out.both(format!("LOGUP {} {} {}", f2(&beta), f2(&gamma), f2(&alpha)));
    // the public data the lookup side's tables are built from
    let acc_pub = blk.accuracy().expect("the W16R2 rung carries accuracy data");
    let exp = &blk.attention().exp;
    assert!(exp.len() >= 256, "the exp table has at least 256 entries");
    out.both(format!("EXP {} {}", exp.len(), ints(&exp[..256])));
    let tables = acc_pub.scaled_tables();
    out.both(format!("NG {}", acc_pub.groups().len()));
    assert_eq!(tables.len(), acc_pub.groups().len(), "one scaled ACT table per group");
    for (g, t) in tables.iter().enumerate() {
        out.both(format!("ACT {g} {} {}", t.len(), ints(t)));
    }
    // the verifier's slot kinds (`run_slot` reads `SLOT_KINDS[s]`)
    let kinds: Vec<&str> = (0..sh.n_slots()).map(|s| kind_s(SLOT_KINDS[s])).collect();
    out.both(format!("KINDS {} {}", kinds.len(), kinds.join(",")));
    // the LogUp sum claim `finish_claims` appends to `H`'s claims
    let lc = protocol::logup_sum_claim(&lay);
    out.both(format!("SUMCLAIM {} {}", lc.parts.len(), f2(&lc.value)));
    for (j, p) in lc.parts.iter().enumerate() {
        out.both(format!("PART {j} {} {} {} {}", p.slice.offset, p.slice.log_size, f2(&p.coef), f2s(&p.point)));
    }
    // the slot loop on the real transcript
    let ctx = Ctx { accuracy: blk.accuracy(), lay: &lay, public: blk.attention(), ff: blk.feed_forward(), alpha, beta, g_u8, g_exp, g_act, g_dd };
    let mut side = Side::Verify { slots: &core.slots };
    let mut acc = Acc::default();
    let mut pts = Points::default();
    let (mut n_tabs, mut n_entries) = (0usize, 0usize);
    for s in 0..sh.n_slots() {
        let def = define(s, &ctx, &mut pts, &mut tr).unwrap_or_else(|e| panic!("slot {s}: {e}"));
        if LOOKUP_SLOTS.contains(&s) {
            let pubs: Vec<&Vec<Fp2>> = def.tabs.iter().filter_map(|t| if let Tab::Pub(v) = t { Some(v) } else { None }).collect();
            out.both(format!("SLOT {s} {} {}", def.tabs.len(), pubs.len()));
            for (i, v) in pubs.iter().enumerate() {
                let n = v.len();
                let e = ENDS.min(n);
                out.both(format!(
                    "PUB {s} {i} {n} FP {} {} HEAD {} TAIL {}",
                    f2(&fingerprint(v, rho1)),
                    f2(&fingerprint(v, rho2)),
                    f2s(&v[..e]),
                    f2s(&v[n - e..])
                ));
                out.full_only(format!("FULL {s} {i} {n} {}", f2s(v)));
                n_tabs += 1;
                n_entries += n;
            }
        }
        run_slot(&mut side, &mut acc, def, &mut tr).unwrap_or_else(|e| panic!("slot {s}: {e}"));
    }
    out.both(format!("DONE {n_tabs} {n_entries}"));
    eprintln!("L47 export {}: {n_tabs} public tables, {n_entries} entries; full {} bytes, short {} bytes", sh.name, out.full.len(), out.short.len());
    (out.full, out.short)
}

#[test]
fn lean_l47_export_the_lookup_side() {
    let (full, short) = export(shape::W16R2_RUNG_H24);
    if let Ok(path) = std::env::var("LEAN_L47_CORPUS") {
        std::fs::write(path, full.as_bytes()).unwrap();
    }
    if let Ok(path) = std::env::var("LEAN_L47_CORPUS_SHORT") {
        std::fs::write(path, short.as_bytes()).unwrap();
    }
}
