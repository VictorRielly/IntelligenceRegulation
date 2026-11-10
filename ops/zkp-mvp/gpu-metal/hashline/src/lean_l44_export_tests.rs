//! **D63 Lean lane L44 (2026-11-10): every table of every slot, as `define` builds it on a REAL block receipt, with the
//! claims `run_slot` leaves and the layout's plane offsets** (finding L35-7: the agreement check compared the private
//! tables' plane ids only). TEST ONLY: a child of the test-only `private_block/w16r2_tests.rs` (declared there by one
//! `#[cfg(test)]` line; the file lives in `src/`, not `src/private_block/`, as lanes L10's and L18's do, so
//! `s25_tests`' `TEST_ONLY_FILES` needs no entry). No prover or verifier source changes; nothing here is reachable from
//! a production build.
//!
//! What it does, at the W16R2 development rung (`shape::W16R2_RUNG_H24`) and at the R13 development rung
//! (`shape::R13_RUNG_H24`), each with `w16r2_tests`' seeded block harness (`rung_case`, `prove`, `verify`, `header`):
//! 1. proves one block CORE and verifies it with the production `verify_core`;
//! 2. replays `verify_core`'s head (the `A` root, `M`, `beta`, `gamma`, `alpha`, the `H` root, as lane L11's export does)
//!    and then the slot loop: per slot the production `define` on the real transcript (its draws recovered as L11's),
//!    then the production `run_slot` (`Side::Verify`) on the real transcript;
//! 3. writes per slot, per table in `define`'s order: an `eq` table's start and point; a public table's length and
//!    its values (two base words each) or, above `PUB_EXPORT_MAX` entries, a BLAKE3 digest of its words (16 bytes
//!    each, `Fp2::to_bytes`) and its first and last 16 values; a private table's commitment, every slice (offset,
//!    coefficient), its log size, its coordinates (`Rho k`, `Flip k`, `Fixed v`), its reserved mask row and its
//!    extension round, and the claim `run_slot` pushed for it (`build_claim`'s parts: offset, log size, coefficient,
//!    point; and its value), taken from the accumulator in table order; per slot its draws, its sumcheck point and
//!    extension challenges and its terminal values; and per block the plane offsets `a_off`, `h_off`, every domain's
//!    `rows_of`, and the endpoints' reserved mask rows;
//! 4. writes the W16R2 record to `$LEAN_L44_CORPUS` and the R13 record to `$LEAN_L44_CORPUS_R13`, for
//!    `formal/ZK60Formal/BlockHelperExportCheck.lean` (the W16R2 one against `DefW16.progW16`; the R13 one waits for
//!    an R13 program).
//!
//! Every value is public: the fixture's public synthetic data, the receipt and the transcript's challenges, the claims
//! the verifier computes (no witness value, no mask coefficient, no RNG state is written).
use super::super::argument::{define, run_slot, Acc, Cm, Coord, Ctx, Points, Side, Tab};
use super::*;
use crate::sumcheck;
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

fn hex(b: &[u8]) -> String {
    b.iter().map(|x| format!("{x:02x}")).collect()
}

fn nums(v: &[usize]) -> String {
    if v.is_empty() {
        "-".to_string()
    } else {
        v.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(",")
    }
}

fn cm_s(c: Cm) -> &'static str {
    match c {
        Cm::A => "a",
        Cm::H => "h",
        Cm::In => "inp",
        Cm::Out => "out",
    }
}

fn coord_s(c: &Coord) -> String {
    match c {
        Coord::Rho(k) => format!("r{k}"),
        Coord::Flip(k) => format!("f{k}"),
        Coord::Fixed(v) => format!("x{}:{}", v.c0.0, v.c1.0),
    }
}

/// the largest public table whose values the corpus carries in full
const PUB_EXPORT_MAX: usize = 1 << 10;

/// one block receipt's record (the harness's assertions panic on any disagreement with the production verifier)
fn export(profile: &str) -> String {
    let (sh, blk, w) = rung_case(profile);
    let core = prove(&sh, &blk, copy(&w)).expect("the honest rung core");
    verify(&sh, &blk, &core).expect("the honest rung core verifies (production verify_core)");
    let lay = Layout::for_shape(&sh).unwrap();
    let mut out = String::new();
    writeln!(out, "L44 {} {} {} {} {} {}", sh.name, sh.n_slots(), lay.a_off.len(), lay.h_off.len(), sh.log_cols, sh.endpoint_log_n).unwrap();
    // per block: the domains' rows, the planes' offsets, the endpoints' reserved pairs
    let doms = [Dom::T, Dom::Ht, Dom::L, Dom::D, Dom::Q, Dom::Kv, Dom::S, Dom::F, Dom::Tab];
    let rows: Vec<usize> = doms.iter().map(|d| sh.rows_of(*d)).collect();
    writeln!(out, "ROWS {}", nums(&rows)).unwrap();
    writeln!(out, "AOFF {}", nums(&lay.a_off)).unwrap();
    let hoff: Vec<usize> = lay.h_off.iter().flat_map(|(re, im)| [*re, *im]).collect();
    writeln!(out, "HOFF {}", nums(&hoff)).unwrap();
    writeln!(out, "IO {} {}", lay.io_mask_row(false), lay.io_mask_row(true)).unwrap();
    // `verify_core`'s head (protocol.rs, as lane L11's export replays it)
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
    writeln!(out, "LOGUP {} {} {}", f2(&beta), f2(&gamma), f2(&alpha)).unwrap();
    let ctx = Ctx { accuracy: blk.accuracy(), lay: &lay, public: blk.attention(), ff: blk.feed_forward(), alpha, beta, g_u8, g_exp, g_act, g_dd };
    let mut side = Side::Verify { slots: &core.slots };
    let mut acc = Acc::default();
    let mut pts = Points::default();
    let mut scalars: Vec<Fp2> = Vec::new();
    let (mut n_priv_all, mut n_pub_full, mut n_pub_digest, mut n_eq) = (0usize, 0usize, 0usize, 0usize);
    for s in 0..sh.n_slots() {
        let before_def = Transcript::clone_state(&tr);
        let def = define(s, &ctx, &mut pts, &mut tr).unwrap_or_else(|e| panic!("slot {s}: {e}"));
        // the definition's draws: `define` only squeezes (lane L11's recovery)
        let mut replay = Transcript::clone_state(&before_def);
        let mut draws = Vec::new();
        while replay.counter() < tr.counter() {
            draws.push(replay.challenge_fp2());
        }
        assert_eq!(replay.state(), tr.state(), "slot {s}: the definition did more than squeeze");
        let (n, ext, _degree) = sh.slots()[s];
        writeln!(out, "SLOT {s} {n} {ext} {}", def.tabs.len()).unwrap();
        writeln!(out, "DRAWS {}", f2s(&draws)).unwrap();
        let sp = &core.slots[s];
        writeln!(out, "TERMS {}", f2s(&sp.terms)).unwrap();
        // the tables, in `define`'s order
        for (i, t) in def.tabs.iter().enumerate() {
            match t {
                Tab::Eq { point, start } => {
                    writeln!(out, "EQ {i} {start} {}", f2s(point)).unwrap();
                    n_eq += 1;
                }
                Tab::Pub(v) => {
                    if v.len() <= PUB_EXPORT_MAX {
                        writeln!(out, "PUB {i} {} V {}", v.len(), f2s(v)).unwrap();
                        n_pub_full += 1;
                    } else {
                        let mut bytes = Vec::with_capacity(16 * v.len());
                        for x in v {
                            bytes.extend_from_slice(&x.to_bytes());
                        }
                        let d = blake3::hash(&bytes);
                        writeln!(out, "PUB {i} {} D {} {} {}", v.len(), hex(d.as_bytes()), f2s(&v[..16]), f2s(&v[v.len() - 16..])).unwrap();
                        n_pub_digest += 1;
                    }
                }
                Tab::Priv(p) => {
                    let sl: Vec<String> = p.slices.iter().map(|(off, c)| format!("{off}:{}", f2(c))).collect();
                    let co: Vec<String> = p.coords.iter().map(coord_s).collect();
                    writeln!(
                        out,
                        "PRIV {i} {} {} {} {} {} {}",
                        cm_s(p.cm),
                        p.log,
                        p.mask_row,
                        p.ext_round,
                        sl.join(";"),
                        if co.is_empty() { "-".to_string() } else { co.join(",") }
                    )
                    .unwrap();
                    n_priv_all += 1;
                }
            }
        }
        // the slot's sumcheck point and extension challenges: `run_slot`'s VERIFY arm (argument.rs) recomputed on a
        // clone, as lane L11's export does
        let mut t2 = Transcript::clone_state(&tr);
        t2.absorb_u64(b"pb-slot", s as u64);
        let _c = t2.challenge_fp2();
        t2.absorb_fp2(b"pb-scalar", &[sp.scalar]);
        let claimed = def.hosted.iter().fold(sp.scalar, |a, (hs, coef)| a.add(coef.mul(scalars[*hs])));
        let (_fin, rho_full) = sumcheck::verify(claimed, sh.slots()[s].2, n + ext, &sp.sc, &mut t2).expect("an honest slot verifies");
        writeln!(out, "RHO {} {}", f2s(&rho_full[..n]), f2s(&rho_full[n..])).unwrap();
        // the production `run_slot`'s VERIFY arm on the real transcript; the claims it pushed, per commitment
        let before: Vec<usize> = acc.claims.iter().map(|c| c.len()).collect();
        let cm_of: Vec<Option<Cm>> = def.tabs.iter().map(|t| if let Tab::Priv(p) = t { Some(p.cm) } else { None }).collect();
        run_slot(&mut side, &mut acc, def, &mut tr).unwrap_or_else(|e| panic!("slot {s}: {e}"));
        scalars.push(sp.scalar);
        let mut next = before.clone();
        for (i, c) in cm_of.iter().enumerate() {
            if let Some(cm) = c {
                let k = *cm as usize;
                let cl = &acc.claims[k][next[k]];
                next[k] += 1;
                let parts: Vec<String> = cl.parts.iter().map(|p| format!("{}:{}:{}:{}", p.slice.offset, p.slice.log_size, f2(&p.coef), f2s(&p.point))).collect();
                writeln!(out, "CLAIM {i} {} {} {}", cm_s(*cm), f2(&cl.value), parts.join("|")).unwrap();
            }
        }
        for k in 0..4 {
            assert_eq!(next[k], acc.claims[k].len(), "slot {s}: every claim pushed belongs to a private table");
        }
        writeln!(out, "END {s}").unwrap();
    }
    writeln!(out, "DONE {} {n_priv_all} {n_pub_full} {n_pub_digest} {n_eq}", sh.n_slots()).unwrap();
    eprintln!(
        "L44 export {}: {} slots, {n_priv_all} private, {n_pub_full} public in full, {n_pub_digest} public by digest, {n_eq} eq tables, {} bytes",
        sh.name,
        sh.n_slots(),
        out.len()
    );
    out
}

#[test]
fn lean_l44_export_the_rung_tables() {
    let w16 = export(shape::W16R2_RUNG_H24);
    if let Ok(path) = std::env::var("LEAN_L44_CORPUS") {
        std::fs::write(path, w16.as_bytes()).unwrap();
    }
    let r13 = export(shape::R13_RUNG_H24);
    if let Ok(path) = std::env::var("LEAN_L44_CORPUS_R13") {
        std::fs::write(path, r13.as_bytes()).unwrap();
    }
}
