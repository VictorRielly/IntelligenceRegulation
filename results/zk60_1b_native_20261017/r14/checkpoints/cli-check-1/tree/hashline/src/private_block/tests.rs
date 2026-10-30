//! Unit tests of the experimental private block profile. Every fixture here
//! is the PUBLIC SYNTHETIC one (`AttentionPublic::synthetic_fixture`): no real
//! input, model or secret is involved, and nothing is written to disk.
//! Run in release (`cargo test --release`): each leg is a full proof.

use super::argument::{argument, Cm, Ctx, Side};
use super::layout::*;
use super::protocol::{audit_claims, check_opening, check_opening_challenges, prove_inner, transcript, verify_inner};
use super::witness::{self, Witness};
use super::*;
use crate::field::{Fp, Fp2};
use crate::pcs::{Slice, ZClaim, ZPart};
use crate::tables_attn::{TAG_ACT, TAG_EXP, TAG_U8};

fn spec() -> IoSpec {
    IoSpec::new(*blake3::hash(b"private block: public synthetic test context").as_bytes(), 0, 0).unwrap()
}

fn fixture() -> (BlockPublic, Vec<i16>, Vec<i16>) {
    let (blk, input) = BlockPublic::synthetic_fixture();
    let output = compute_output(&blk, &input).unwrap();
    (blk, input, output)
}

fn honest() -> (BlockPublic, ExpectedIo, Receipt, ProveStats) {
    let (blk, input, output) = fixture();
    let (expected, owners) = prepare_endpoints(spec(), &input, &output).unwrap();
    let (receipt, stats) = prove_with_stats(&blk, &input, &expected, owners).unwrap();
    (blk, expected, receipt, stats)
}

/// Disposition condition 5 and D12 item 5: the two endpoint exponents are
/// pinned to the approved calibration by a CONSTRUCTOR REFUSAL, and the
/// calibration identity this profile absorbs is that calibration's.
#[test]
fn the_endpoint_scales_and_calibration_are_the_approved_ones() {
    let ctx = *blake3::hash(b"private block: scale pinning").as_bytes();
    // the value the accepted attention component's fixtures declare, refused here
    assert!(IoSpec::new(ctx, -3, -3).is_err());
    for (a, b) in [(-3, 0), (0, -3), (1, 0), (0, 1)] {
        assert!(IoSpec::new(ctx, a, b).is_err(), "IoSpec accepted ({a}, {b})");
    }
    let spec = IoSpec::new(ctx, 0, 0).unwrap();
    // ... and they are the approved calibration's own e_r and e_r2
    let dummy = crate::pcs::Commitment { root: [0; 32], rows: 1, log_cols: LOG_N as u32 };
    let reg = crate::causal_oracle::public_synthetic_registration(dummy.clone(), dummy);
    assert_eq!((spec.input_scale(), spec.output_scale()), (reg.attention.e_r, reg.residual.e_r2));
    assert_eq!((spec.input_scale(), spec.output_scale()), ENDPOINT_SCALES);
    // the literal this module absorbs IS the registration's identity digest
    assert_eq!(calibration_identity(), reg.calibration_identity);
}

#[test]
fn witness_equals_the_independent_fixed_causal_oracle() {
    let (contract, weights, input) = crate::causal_oracle::public_synthetic_fixture();
    let oracle = crate::causal_oracle::FixedCausalOracle::new(&contract, weights).expect("oracle weights");
    let block = oracle.build(&input).expect("oracle accepts the public fixture");
    let a = &block.attention;
    let (blk, x) = BlockPublic::synthetic_fixture();
    assert_eq!(x, input);
    let w = witness::build(blk.attention(), blk.feed_forward(), &x).unwrap();
    for (plane, want, name) in [
        (A_Y, &a.na.y, "norm y"),
        (A_D, &a.na.dd, "norm D"),
        (A_Q8, &a.q8, "q8"),
        (A_K8, &a.k8, "k8"),
        (A_V8, &a.v8, "v8"),
        (A_QR8, &a.qr8, "qr8"),
        (A_KR8, &a.kr8, "kr8"),
        (A_S8, &a.s8, "s8"),
        (A_ZSEL, &a.zsel, "zsel"),
        (A_E, &a.e_t, "exp"),
        (A_P, &a.p, "p"),
        (A_MX, &a.m_row, "row max"),
        (A_SUM, &a.sum, "row sum"),
        (A_O8, &a.o8, "o8"),
        (A_AO, &a.ao8, "ao"),
        (A_X1, &a.xres1, "xres1"),
    ] {
        assert!(w.planes[plane] == *want, "plane {name} differs from the oracle");
    }
    // biased remainder limbs against the oracle's signed remainders
    assert!(w.planes[A_RQL].iter().zip(&a.rq).all(|(l, r)| *l == r + 64));
    assert!(w.planes[A_RSL].iter().zip(&a.rs).all(|(l, r)| *l == r + 32));
    assert!(w.planes[A_RO0].iter().zip(&w.planes[A_RO1]).zip(&a.r_o).all(|((l0, l1), r)| l0 + 256 * l1 == r + 256));
    // the OUTPUT plane is the block's, xres2: the oracle's own residual 2
    assert!(w.planes[A_X2] == block.residual.xres2, "xres2 differs from the oracle");
    assert_eq!(w.output().unwrap(), block.residual.xres2.iter().map(|v| *v as i16).collect::<Vec<i16>>());
}

#[test]
fn honest_receipt_verifies_in_typed_and_wire_form_with_the_declared_transcript_order() {
    let (blk, expected, receipt, stats) = honest();
    let order = verify_inner(&blk, &expected, &receipt).unwrap();
    assert_eq!(order, stats.transcript_order, "prover and verifier absorb sequences differ");
    assert_eq!(order.len(), 3 * N_SLOTS);
    for s in 0..N_SLOTS {
        assert_eq!(order[3 * s], format!("slot {s:02} begin"));
    }
    let bytes = receipt.to_bytes(&blk, &expected).unwrap();
    assert_eq!(bytes.len(), encoded_len());
    assert!(bytes.len() <= MAX_WIRE_BYTES);
    verify_bytes(&blk, &expected, &bytes).unwrap();
    // shape facts are constants of the geometry, not of the witness; the
    // frame length is the design's derived whole-block figure (T2 section D.3)
    assert_eq!((stats.a_rows, stats.h_rows, stats.m_rows), (455, 384, 50));
    assert_eq!((stats.u8_lookups, stats.exp_lookups, stats.act_lookups), (61_440, 2_048, 512));
    assert_eq!(bytes.len(), 2_816_472);
}

/// SMOKE TEST, not a privacy argument: no published field word is a small integer
/// (a plaintext int8/int16 plane value, a histogram count or a clear row sum would be).
#[test]
fn no_published_word_is_a_small_integer() {
    let (_, _, r, _) = honest();
    let mut words: Vec<u64> = Vec::new();
    let push2 = |words: &mut Vec<u64>, v: &Fp2| words.extend([v.c0.0, v.c1.0]);
    for sp in &r.slots {
        push2(&mut words, &sp.scalar);
        sp.terms.iter().for_each(|v| push2(&mut words, v));
        sp.sc.rounds.iter().flatten().for_each(|v| push2(&mut words, v));
    }
    r.mask_open.q.iter().chain(r.mask_open.prox.iter()).for_each(|v| push2(&mut words, v));
    r.mask_open.columns.iter().for_each(|(_, c, _, _)| words.extend(c.iter().map(|x| x.0)));
    for o in [&r.a_open, &r.h_open, &r.io_open[0], &r.io_open[1]] {
        o.group_vecs.iter().flatten().chain(o.prox_vec.iter()).for_each(|v| push2(&mut words, v));
        o.columns.iter().for_each(|(_, c, _, _)| words.extend(c.iter().map(|x| x.0)));
    }
    assert!(words.len() > 200_000);
    let lim = 1u64 << 24;
    let small = words.iter().filter(|w| **w < lim || **w > crate::field::P - lim).count();
    assert_eq!(small, 0, "a published word lies in the witness range");
}

fn prove_tampered(edit: impl FnOnce(&mut Witness)) -> Result<(), String> {
    let (blk, input, output) = fixture();
    let (expected, owners) = prepare_endpoints(spec(), &input, &output).unwrap();
    let mut w = witness::build(blk.attention(), blk.feed_forward(), &input).unwrap();
    edit(&mut w);
    // the prover does not pre-check the relation: a false witness yields a receipt that must not verify
    let (receipt, _) = prove_inner(&blk, w, &expected, owners)?;
    verify(&blk, &expected, &receipt)
}

#[test]
fn every_relation_family_rejects_an_inconsistent_witness() {
    let s_idx = 3 * T + 1; // head 0, query 3, key 1 (on the causal support)
    let cases: Vec<(&str, Box<dyn FnOnce(&mut Witness)>)> = vec![
        ("isqrt D", Box::new(|w: &mut Witness|w.planes[A_D][2] += 1)),
        ("norm quotient", Box::new(|w: &mut Witness|w.planes[A_Y][5] += 1)),
        ("Q projection", Box::new(|w: &mut Witness|w.planes[A_Q8][7] += 1)),
        ("V projection", Box::new(|w: &mut Witness|w.planes[A_V8][9] += 1)),
        ("RoPE", Box::new(|w: &mut Witness|w.planes[A_QR8][20] += 1)),
        ("score", Box::new(move |w: &mut Witness|w.planes[A_S8][s_idx] += 1)),
        ("row max", Box::new(|w: &mut Witness|w.planes[A_MX][3] += 1)),
        ("second selector", Box::new(move |w: &mut Witness|w.planes[A_ZSEL][s_idx + 1] = 1 - w.planes[A_ZSEL][s_idx + 1])),
        ("exp value", Box::new(move |w: &mut Witness|w.planes[A_E][s_idx] += 1)),
        ("row sum", Box::new(|w: &mut Witness|w.planes[A_SUM][3] += 1)),
        ("softmax quotient", Box::new(move |w: &mut Witness|w.planes[A_P][s_idx] += 1)),
        ("acausal weight", Box::new(|w: &mut Witness|w.planes[A_P][2 * T + 9] = 1)),
        ("PV output", Box::new(|w: &mut Witness|w.planes[A_O8][9] += 1)),
        ("output projection", Box::new(|w: &mut Witness|w.planes[A_AO][9] += 1)),
        ("residual 1", Box::new(|w: &mut Witness|w.planes[A_X1][0] += 1)),
        ("residual 2 / output endpoint", Box::new(|w: &mut Witness|w.planes[A_X2][0] += 1)),
        ("input endpoint", Box::new(|w: &mut Witness|w.planes[A_X][0] += 1)),
        // algebra preserved, only the range broken: x + 32768 = (l0 + 256) + 256 (l1 - 1)
        ("range only (LogUp)", Box::new(|w: &mut Witness|{
            w.planes[A_XL0][11] += 256;
            w.planes[A_XL1][11] -= 1;
        })),
    ];
    for (name, edit) in cases {
        let got = prove_tampered(edit);
        assert!(got.is_err(), "tamper `{name}` verified");
    }
    // control: the identity edit verifies through the same path
    prove_tampered(|_| {}).unwrap();
}

#[test]
fn an_endpoint_committed_to_other_values_is_refused() {
    let (blk, input, output) = fixture();
    for which in 0..2 {
        let (mut i2, mut o2) = (input.clone(), output.clone());
        if which == 0 { i2[17] += 1 } else { o2[17] += 1 }
        let (expected, owners) = prepare_endpoints(spec(), &i2, &o2).unwrap();
        let receipt = prove(&blk, &input, &expected, owners).unwrap();
        assert!(verify(&blk, &expected, &receipt).is_err(), "endpoint {which}");
    }
    // owners prepared under another context or for another policy never reach proving
    let (expected, _) = prepare_endpoints(spec(), &input, &output).unwrap();
    let (_, other) = prepare_endpoints(spec(), &input, &output).unwrap();
    assert!(prove(&blk, &input, &expected, other).is_err(), "fresh owners have other roots");
}

#[test]
fn receipt_field_tampers_and_statement_mismatches_are_refused() {
    let (blk, expected, receipt, _) = honest();
    let bytes = receipt.to_bytes(&blk, &expected).unwrap();
    let copy = || Receipt::from_bytes(&blk, &expected, &bytes).unwrap();
    let one = Fp2::ONE;
    let edits: Vec<(&str, Box<dyn Fn(&mut Receipt)>)> = vec![
        ("private masked scalar", Box::new(move |r: &mut Receipt|r.slots[SC_RS].scalar = r.slots[SC_RS].scalar.add(one))),
        ("host Gamma", Box::new(move |r: &mut Receipt|r.slots[SC_SZC].scalar = r.slots[SC_SZC].scalar.add(one))),
        ("standalone Gamma", Box::new(move |r: &mut Receipt|r.slots[SC_TAB].scalar = r.slots[SC_TAB].scalar.add(one))),
        ("terminal", Box::new(move |r: &mut Receipt|r.slots[SC_DZC].terms[4] = r.slots[SC_DZC].terms[4].add(one))),
        ("round message", Box::new(move |r: &mut Receipt|r.slots[SC_PV].sc.rounds[2][1] = r.slots[SC_PV].sc.rounds[2][1].add(one))),
        ("extension round", Box::new(move |r: &mut Receipt|r.slots[SC_SCORE].sc.rounds[4][2] = r.slots[SC_SCORE].sc.rounds[4][2].add(one))),
        ("swapped slots", Box::new(|r: &mut Receipt|r.slots.swap(SC_KMM, SC_VMM))),
        ("M product polynomial", Box::new(move |r: &mut Receipt|r.mask_open.q[3] = r.mask_open.q[3].add(one))),
        ("A group vector", Box::new(move |r: &mut Receipt|r.a_open.group_vecs[7][5] = r.a_open.group_vecs[7][5].add(one))),
        ("A pad entry", Box::new(move |r: &mut Receipt|r.a_open.group_vecs[0][300] = r.a_open.group_vecs[0][300].add(one))),
        ("H LogUp sum vector", Box::new(move |r: &mut Receipt|r.h_open.group_vecs[H_GROUPS - 1][0] = r.h_open.group_vecs[H_GROUPS - 1][0].add(one))),
        ("H column", Box::new(|r: &mut Receipt|r.h_open.columns[0].1[0] = r.h_open.columns[0].1[0].add(crate::field::Fp::ONE))),
        ("A salt", Box::new(|r: &mut Receipt|r.a_open.columns[1].2[0] ^= 1)),
        ("endpoint proximity", Box::new(move |r: &mut Receipt|r.io_open[1].prox_vec[0] = r.io_open[1].prox_vec[0].add(one))),
        ("swapped endpoint openings", Box::new(|r: &mut Receipt|r.io_open.swap(0, 1))),
        ("A root", Box::new(|r: &mut Receipt|r.a_root[0] ^= 1)),
        ("H root", Box::new(|r: &mut Receipt|r.h_root[0] ^= 1)),
        ("M root", Box::new(|r: &mut Receipt|r.mask_root[0] ^= 1)),
        ("missing slot", Box::new(|r: &mut Receipt|{ r.slots.pop(); })),
    ];
    for (name, edit) in &edits {
        let mut r = copy();
        edit(&mut r);
        assert!(verify(&blk, &expected, &r).is_err(), "edit `{name}` verified");
    }
    verify(&blk, &expected, &copy()).unwrap();

    // the verifier's OWN statement decides: every public word is in the ONE
    // statement digest, the attention words and the feed-forward words alike
    let (w, _) = AttentionPublic::synthetic_fixture();
    let f = FeedForwardPublic::synthetic_fixture();
    for which in 0..6 {
        let (mut wq, mut gm, mut wg, mut wu, mut wd, mut act) = (w.wq.clone(), f.gamma_m.clone(), f.wg_t.clone(), f.wu_t.clone(), f.wd_t.clone(), f.act);
        match which {
            0 => wq[0] += 1,
            1 => gm[2] += 1,
            2 => wg[5] += 1,
            3 => wu[6] += 1,
            4 => wd[7] += 1,
            _ => act[131] += 1,
        }
        let other = BlockPublic::new(
            AttentionPublic::new(&wq, &w.wk, &w.wv, &w.wo, &w.gamma_a, &w.rope_cos, &w.rope_sin, &w.exp).unwrap(),
            FeedForwardPublic::new(&gm, &wg, &wu, &wd, &act).unwrap(),
        );
        assert!(verify(&other, &expected, &receipt).is_err(), "public word {which} accepted");
        assert!(Receipt::from_bytes(&other, &expected, &bytes).is_err(), "public word {which} parsed");
    }
    let other_ctx = IoSpec::new(*blake3::hash(b"another context").as_bytes(), 0, 0).unwrap();
    let moved = ExpectedIo::from_roots(other_ctx, expected.input_root(), expected.output_root());
    assert!(verify(&blk, &moved, &receipt).is_err());
    assert!(verify_bytes(&blk, &moved, &bytes).is_err());
    let swapped = ExpectedIo::from_roots(spec(), expected.output_root(), expected.input_root());
    assert!(verify(&blk, &swapped, &receipt).is_err());
}

#[test]
fn wire_frames_are_exact_canonical_and_bounded() {
    let (blk, expected, receipt, _) = honest();
    let bytes = receipt.to_bytes(&blk, &expected).unwrap();
    let parse = |b: &[u8]| Receipt::from_bytes(&blk, &expected, b).map(|_| ());
    parse(&bytes).unwrap();
    assert!(parse(&bytes[..bytes.len() - 1]).is_err(), "truncated");
    let mut long = bytes.clone();
    long.push(0);
    assert!(parse(&long).is_err(), "trailing byte");
    let mut magic = bytes.clone();
    magic[7] ^= 1;
    assert!(parse(&magic).is_err(), "profile byte");
    let mut bind = bytes.clone();
    bind[9] ^= 1;
    assert!(parse(&bind).is_err(), "statement binding");
    // the first slot scalar's first limb, made noncanonical (>= p)
    let mut word = bytes.clone();
    let at = wire::HEADER + 3 * 32;
    word[at..at + 8].copy_from_slice(&u64::MAX.to_le_bytes());
    assert!(parse(&word).is_err(), "noncanonical field word");
    // a column index outside the encoded domain (first M column index follows q and prox)
    let slots: usize = (0..N_SLOTS).map(|s| (1 + (SLOTS[s].0 + SLOTS[s].1) * (SLOTS[s].2 + 1) + slot_terms(s)) * 16).sum();
    let at = wire::HEADER + 3 * 32 + slots + 2 * 1024 * 16;
    let mut col = bytes.clone();
    col[at..at + 8].copy_from_slice(&4096u64.to_le_bytes());
    assert!(parse(&col).is_err(), "column index bound");
    assert!(parse(&vec![0u8; MAX_WIRE_BYTES + 1]).is_err(), "oversized");
    // the expected-policy frame
    let e = expected.to_bytes();
    assert_eq!(e.len(), EXPECTED_BYTES);
    assert_eq!(ExpectedIo::from_bytes(&e).unwrap(), expected);
    assert!(ExpectedIo::from_bytes(&e[1..]).is_err());
}

#[test]
fn opening_refusals_are_functions_of_the_challenges_only() {
    let v = |a: u64, b: u64| Fp2::new(crate::field::Fp::new(a), crate::field::Fp::new(b));
    let run = |draws: Vec<Fp2>, groups: &[usize], rows: usize, prox: usize| {
        let mut it = draws.into_iter();
        check_opening_challenges(groups, rows, prox, || it.next().expect("enough draws"))
    };
    // two groups (2 + 1 members), 4 rows, proximity pair (2, 3)
    let good = vec![v(1, 2), v(3, 4), v(5, 6), v(7, 8), v(9, 1), v(1, 0), v(0, 1)];
    run(good.clone(), &[2, 1], 4, 2).unwrap();
    let mut zero_member = good.clone();
    zero_member[1] = Fp2::ZERO;
    assert!(run(zero_member, &[2, 1], 4, 2).unwrap_err().contains("zero group member"));
    // proximity coefficients (2 + 4u, 1 + 2u) are Fp-dependent: one base-field row would stay unmasked
    let mut dependent = good.clone();
    dependent[5] = v(2, 4);
    dependent[6] = v(1, 2);
    assert!(run(dependent, &[2, 1], 4, 2).unwrap_err().contains("dependent proximity"));
    let mut zero_prox = good;
    zero_prox[6] = Fp2::ZERO;
    assert!(run(zero_prox, &[2, 1], 4, 2).is_err());
}

#[test]
fn the_schedule_audit_refuses_shared_missing_and_foreign_mask_rows() {
    let pt: Vec<Fp2> = (0..8).map(|i| Fp2::new(crate::field::Fp::new(11 + i), crate::field::Fp::new(3 + 2 * i))).collect();
    let part = |row: usize, coef: Fp2| ZPart { slice: Slice { offset: row * N, log_size: LOG_N as u32 }, coef, point: pt.clone() };
    let claim = |data: usize, pair: usize| ZClaim { parts: vec![part(data, Fp2::ONE), part(pair, Fp2::U), part(pair + 1, Fp2::U.mul(Fp2::U))], value: Fp2::ZERO };
    // rows: data 0..4, reserved pairs (4,5) (6,7), proximity pair (8,9)
    let sites = [4usize, 5, 6, 7];
    audit_claims(&[claim(0, 4), claim(1, 6)], N, 10, &sites, None, 8).unwrap();
    assert!(audit_claims(&[claim(0, 4), claim(1, 4)], N, 10, &sites, None, 8).is_err(), "a pair shared by two claims");
    assert!(audit_claims(&[claim(0, 4)], N, 10, &sites, None, 8).is_err(), "an unused reserved pair");
    assert!(audit_claims(&[claim(0, 5), claim(1, 6)], N, 10, &sites, None, 8).is_err(), "a misaligned pair");
    assert!(audit_claims(&[claim(0, 4), claim(1, 8)], N, 10, &sites, None, 8).is_err(), "a claim on the proximity pair");
    let mut dead = claim(1, 6);
    dead.parts[1].coef = Fp2::ZERO;
    assert!(audit_claims(&[claim(0, 4), dead], N, 10, &sites, None, 8).is_err(), "a zero mask coefficient");
    let unmasked = ZClaim { parts: vec![part(2, Fp2::ONE)], value: Fp2::ZERO };
    assert!(audit_claims(&[claim(0, 4), claim(1, 6), unmasked], N, 10, &sites, None, 8).is_err(), "an unmasked claim");
}

/// DEFECT D-2 of the 2026-09-19 code review: `witness::requant` computed its
/// rounding bias as `1i64 << (sh - 1)` with `sh: u32`, so at `sh = 0` the
/// subtraction underflowed to `u32::MAX` — a panic in debug, a masked shift in
/// release. Nothing reaches it today (the up matmul, this profile's only
/// `SH_U = 0` site, bypasses `quantize` deliberately), which is exactly why it
/// needs a test rather than an argument. Two claims: the map is the identity
/// with no remainder at shift 0, and at every shift the profile uses it is the
/// integer reference's own requantization with the documented remainder.
#[test]
fn requant_is_the_identity_at_shift_zero_and_the_kernels_rounding_above_it() {
    use private_block_kernel as kern;
    assert_eq!(witness::half(0), 0);
    for v in [0i64, 1, -1, 2, -2, 127, -128, 8191, -8192, 32767, -32768, 1 << 40, -(1 << 40)] {
        assert_eq!(witness::requant(v, 0), (v, 0), "requant({v}, 0) is not the identity");
        // the kernel's own rule at a non-positive shift: exact up-scaling by 2^0
        assert_eq!(witness::requant(v, 0).0, kern::requant(v, 0, "test").expect("no overflow"));
    }
    // `acc = y 2^sh + r` with `r` in [-2^(sh-1), 2^(sh-1)), the biased limb
    // `r + 2^(sh-1)` (what `quantize` commits) in [0, 2^sh), and `y` the
    // kernel's value — over four full periods each side of zero, so every
    // residue, both rounding ties and both signs are swept.
    for sh in 1..=14u32 {
        let (step, half) = (1i64 << sh, 1i64 << (sh - 1));
        assert_eq!(witness::half(sh), half);
        for acc in -4 * step..=4 * step {
            let (y, r) = witness::requant(acc, sh);
            assert_eq!(acc, y * step + r, "the requantization identity at sh={sh}, acc={acc}");
            assert!((-half..half).contains(&r), "remainder outside its window at sh={sh}, acc={acc}");
            assert!((0..step).contains(&(r + witness::half(sh))), "biased limb outside [0, 2^{sh}) at acc={acc}");
            assert_eq!(y, kern::requant(acc, sh as i32, "test").expect("no overflow"), "kernel parity at sh={sh}, acc={acc}");
        }
    }
}

/// the two reserved-pair rows a claim carries (`build_claim` pushes the pair
/// parts last, in row order)
fn pair_rows(c: &ZClaim) -> [usize; 2] {
    let n = c.parts.len();
    [c.parts[n - 2].slice.offset / N, c.parts[n - 1].slice.offset / N]
}

fn absorb_root(tr: &mut crate::transcript::Transcript, label: &[u8], root: &[u8; 32], rows: usize) {
    tr.absorb(label, root);
    tr.absorb_u64(b"rows", rows as u64);
    tr.absorb_u64(b"log-cols", LOG_N as u64);
}

/// The claim list the VERIFIER really builds for `A`, and the transcript state
/// at the moment it audits it: `verify_inner`'s own steps in its own order
/// (`protocol.rs:436-452`), with nothing simulated.
fn verifier_a_claims(blk: &BlockPublic, expected: &ExpectedIo, receipt: &Receipt) -> (Vec<ZClaim>, crate::transcript::Transcript) {
    let lay = Layout::new();
    let ntt = crate::ntt::NttTables::new(12);
    let mut tr = transcript(blk, expected, &lay);
    absorb_root(&mut tr, b"A", &receipt.a_root, lay.a_rows);
    tr.absorb(b"M", &receipt.mask_root);
    let beta = tr.challenge_fp2();
    let gamma = tr.challenge_fp2();
    let alpha = tr.challenge_fp2();
    let (g_u8, g_exp, g_act) = (gamma.mul_base(Fp::new(TAG_U8)), gamma.mul_base(Fp::new(TAG_EXP)), gamma.mul_base(Fp::new(TAG_ACT)));
    absorb_root(&mut tr, b"H", &receipt.h_root, lay.h_rows);
    let ctx = Ctx { accuracy:None, lay: &lay, public: blk.attention(), ff: blk.feed_forward(), alpha, beta, g_u8, g_exp, g_act, g_dd: crate::field::Fp2::ZERO };
    let mut side = Side::Verify { slots: &receipt.slots };
    let mut ph = super::timing::Phases::start();
    let acc = argument(&mut side, &ctx, &mut tr, &mut ph).expect("the honest receipt's slots verify");
    crate::zk::mask_verify(&receipt.mask_root, &mask_specs(), &acc.fs, &receipt.mask_open, &ntt, &mut tr).expect("the M opening verifies");
    (acc.claims[Cm::A as usize].clone(), tr)
}

/// OWED by the S5 ledger entry: the claim audit is exercised on HAND-BUILT
/// lists by `the_schedule_audit_refuses_shared_missing_and_foreign_mask_rows`,
/// never on the list the argument really builds. This runs the verifier's own
/// `argument()` over an honest receipt — the same call `verify_inner` makes
/// (`protocol.rs:448`), producing the very list it audits (`:452`) — and puts
/// that REAL list through `check_opening` with the exact arguments BOTH sides
/// pass (`prove_inner` `:396` and `verify_inner` `:452`: `lay.a_rows`,
/// `lay.a_site_rows()`, no sum pair, `lay.a_prox`, `A_GROUPS`). Two planes
/// sharing one reserved pair, and a reserved pair no claim consumes, are both
/// refused, by name.
///
/// WHAT IT DOES NOT DO, plainly: it does not force a degenerate list through
/// `prove_inner` or `verify_inner` end to end. Which pair a site gets is
/// `lay.a_site(slot, k)`, a function of the fixed layout alone, so no witness,
/// receipt or public word can make the real list share or orphan a pair; the
/// only way in from a test would be a hook inside `protocol.rs`, i.e. a
/// release-reachable path, which is worse than the gap it would close. The
/// prover audits the same structure: `run_slot` appends one `build_claim` per
/// private table on both sides, from the same `def.tabs` and the same
/// `p.mask_row`, and
/// `honest_receipt_verifies_in_typed_and_wire_form_with_the_declared_transcript_order`
/// pins that the two sides walk the same slots in the same order.
#[test]
fn the_real_claim_list_is_refused_when_a_reserved_pair_is_shared_or_unconsumed() {
    let (blk, expected, receipt, _) = honest();
    let lay = Layout::new();
    let (ac, tr) = verifier_a_claims(&blk, &expected, &receipt);
    let sites = lay.a_site_rows();
    assert_eq!(ac.len(), sites.len() / 2, "one claim per reserved A pair");
    assert!(ac.iter().all(|c| c.parts.len() == 3), "an A claim is one data slice and its pair");
    let audit = |claims: &[ZClaim]| check_opening(claims, LOG_N, lay.a_rows, &sites, None, lay.a_prox, A_GROUPS, &tr);
    audit(&ac).expect("the real claim list passes the audit both sides run");

    // (i) two planes share one reserved pair: the second claim's pair parts are
    // pointed at the first claim's rows, its own pair left with no claim
    let mut shared = ac.clone();
    let row = pair_rows(&ac[0])[0];
    assert_ne!(row, pair_rows(&ac[1])[0], "the two claims must start out on different pairs");
    for j in 0..2 {
        let p = &mut shared[1].parts[1 + j];
        p.slice.offset = (row + j) * N + p.slice.offset % N;
    }
    let err = audit(&shared).expect_err("a shared reserved pair passed the audit");
    assert!(err.contains("unused or shared"), "expected the shared-pair refusal, got `{err}`");

    // (ii) a reserved pair no claim consumes at all
    let mut orphaned = ac.clone();
    orphaned.remove(1);
    let err = audit(&orphaned).expect_err("an unconsumed reserved pair passed the audit");
    assert!(err.contains("unused or shared"), "expected the unconsumed-pair refusal, got `{err}`");
}

#[test]
fn the_declared_schedule_is_stable_and_bound() {
    let lines = schedule();
    assert_eq!(lines.len(), 6 + N_SLOTS + HOSTS.len());
    assert!(lines[0].starts_with("private-block-t32/1"));
    let lay = Layout::new();
    assert_eq!(lay.schedule_digest(), Layout::new().schedule_digest());
    // every reserved pair row lies between the data and the proximity pair, on both commitments
    assert_eq!(lay.a_site(SC_SS, 0).unwrap(), lay.a_data_rows);
    assert_eq!(lay.a_site(SC_IO_OUT, 0).unwrap() + 2, lay.a_prox);
    assert_eq!(lay.h_site(SC_ZS, 0).unwrap() + 2, lay.h_prox);
    assert!(lay.a_site(SC_ZS, 0).is_err() && lay.h_site(SC_SS, 0).is_err());
}
