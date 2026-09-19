//! Unit tests of the experimental private block profile. Every fixture here
//! is the PUBLIC SYNTHETIC one (`AttentionPublic::synthetic_fixture`): no real
//! input, model or secret is involved, and nothing is written to disk.
//! Run in release (`cargo test --release`): each leg is a full proof.

use super::layout::*;
use super::protocol::{audit_claims, check_opening_challenges, prove_inner, verify_inner};
use super::witness::{self, Witness};
use super::*;
use crate::field::Fp2;
use crate::pcs::{Slice, ZClaim, ZPart};

fn spec() -> IoSpec {
    IoSpec::new(*blake3::hash(b"private block: public synthetic test context").as_bytes(), -3, -3).unwrap()
}

fn fixture() -> (AttentionPublic, Vec<i16>, Vec<i16>) {
    let (public, input) = AttentionPublic::synthetic_fixture();
    let output = compute_output(&public, &input).unwrap();
    (public, input, output)
}

fn honest() -> (AttentionPublic, ExpectedIo, Receipt, ProveStats) {
    let (public, input, output) = fixture();
    let (expected, owners) = prepare_endpoints(spec(), &input, &output).unwrap();
    let (receipt, stats) = prove_with_stats(&public, &input, &expected, owners).unwrap();
    (public, expected, receipt, stats)
}

#[test]
fn witness_equals_the_independent_fixed_causal_oracle() {
    let (contract, weights, input) = crate::causal_oracle::public_synthetic_fixture();
    let oracle = crate::causal_oracle::FixedCausalOracle::new(&contract, weights).expect("oracle weights");
    let block = oracle.build(&input).expect("oracle accepts the public fixture");
    let a = &block.attention;
    let (public, x) = AttentionPublic::synthetic_fixture();
    assert_eq!(x, input);
    let w = witness::build(&public, &x).unwrap();
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
    assert_eq!(w.output().unwrap(), a.xres1.iter().map(|v| *v as i16).collect::<Vec<i16>>());
}

#[test]
fn honest_receipt_verifies_in_typed_and_wire_form_with_the_declared_transcript_order() {
    let (public, expected, receipt, stats) = honest();
    let order = verify_inner(&public, &expected, &receipt).unwrap();
    assert_eq!(order, stats.transcript_order, "prover and verifier absorb sequences differ");
    assert_eq!(order.len(), 3 * N_SLOTS);
    for s in 0..N_SLOTS {
        assert_eq!(order[3 * s], format!("slot {s:02} begin"));
    }
    let bytes = receipt.to_bytes(&public, &expected).unwrap();
    assert_eq!(bytes.len(), encoded_len());
    assert!(bytes.len() <= MAX_WIRE_BYTES);
    verify_bytes(&public, &expected, &bytes).unwrap();
    // shape facts are constants of the geometry, not of the witness
    assert_eq!((stats.a_rows, stats.h_rows, stats.m_rows), (306, 290, 40));
    assert_eq!((stats.u8_lookups, stats.exp_lookups), (47_104, 2_048));
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
    let (public, input, output) = fixture();
    let (expected, owners) = prepare_endpoints(spec(), &input, &output).unwrap();
    let mut w = witness::build(&public, &input).unwrap();
    edit(&mut w);
    // the prover does not pre-check the relation: a false witness yields a receipt that must not verify
    let (receipt, _) = prove_inner(&public, &w, &expected, owners)?;
    verify(&public, &expected, &receipt)
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
        ("residual / output endpoint", Box::new(|w: &mut Witness|w.planes[A_X1][0] += 1)),
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
    let (public, input, output) = fixture();
    for which in 0..2 {
        let (mut i2, mut o2) = (input.clone(), output.clone());
        if which == 0 { i2[17] += 1 } else { o2[17] += 1 }
        let (expected, owners) = prepare_endpoints(spec(), &i2, &o2).unwrap();
        let receipt = prove(&public, &input, &expected, owners).unwrap();
        assert!(verify(&public, &expected, &receipt).is_err(), "endpoint {which}");
    }
    // owners prepared under another context or for another policy never reach proving
    let (expected, _) = prepare_endpoints(spec(), &input, &output).unwrap();
    let (_, other) = prepare_endpoints(spec(), &input, &output).unwrap();
    assert!(prove(&public, &input, &expected, other).is_err(), "fresh owners have other roots");
}

#[test]
fn receipt_field_tampers_and_statement_mismatches_are_refused() {
    let (public, expected, receipt, _) = honest();
    let bytes = receipt.to_bytes(&public, &expected).unwrap();
    let copy = || Receipt::from_bytes(&public, &expected, &bytes).unwrap();
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
        assert!(verify(&public, &expected, &r).is_err(), "edit `{name}` verified");
    }
    verify(&public, &expected, &copy()).unwrap();

    // the verifier's OWN statement decides: other weights, other context, other roots
    let (w, _) = AttentionPublic::synthetic_fixture();
    let mut wq = w.wq.clone();
    wq[0] += 1;
    let other_public = AttentionPublic::new(&wq, &w.wk, &w.wv, &w.wo, &w.gamma_a, &w.rope_cos, &w.rope_sin, &w.exp).unwrap();
    assert!(verify(&other_public, &expected, &receipt).is_err());
    assert!(Receipt::from_bytes(&other_public, &expected, &bytes).is_err());
    let other_ctx = IoSpec::new(*blake3::hash(b"another context").as_bytes(), -3, -3).unwrap();
    let moved = ExpectedIo::from_roots(other_ctx, expected.input_root(), expected.output_root());
    assert!(verify(&public, &moved, &receipt).is_err());
    assert!(verify_bytes(&public, &moved, &bytes).is_err());
    let swapped = ExpectedIo::from_roots(spec(), expected.output_root(), expected.input_root());
    assert!(verify(&public, &swapped, &receipt).is_err());
}

#[test]
fn wire_frames_are_exact_canonical_and_bounded() {
    let (public, expected, receipt, _) = honest();
    let bytes = receipt.to_bytes(&public, &expected).unwrap();
    let parse = |b: &[u8]| Receipt::from_bytes(&public, &expected, b).map(|_| ());
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
    audit_claims(&[claim(0, 4), claim(1, 6)], 10, &sites, None, 8).unwrap();
    assert!(audit_claims(&[claim(0, 4), claim(1, 4)], 10, &sites, None, 8).is_err(), "a pair shared by two claims");
    assert!(audit_claims(&[claim(0, 4)], 10, &sites, None, 8).is_err(), "an unused reserved pair");
    assert!(audit_claims(&[claim(0, 5), claim(1, 6)], 10, &sites, None, 8).is_err(), "a misaligned pair");
    assert!(audit_claims(&[claim(0, 4), claim(1, 8)], 10, &sites, None, 8).is_err(), "a claim on the proximity pair");
    let mut dead = claim(1, 6);
    dead.parts[1].coef = Fp2::ZERO;
    assert!(audit_claims(&[claim(0, 4), dead], 10, &sites, None, 8).is_err(), "a zero mask coefficient");
    let unmasked = ZClaim { parts: vec![part(2, Fp2::ONE)], value: Fp2::ZERO };
    assert!(audit_claims(&[claim(0, 4), claim(1, 6), unmasked], 10, &sites, None, 8).is_err(), "an unmasked claim");
}

#[test]
fn the_declared_schedule_is_stable_and_bound() {
    let lines = schedule();
    assert_eq!(lines.len(), 5 + N_SLOTS + HOSTS.len());
    assert!(lines[0].starts_with("private-block-t32-wip/0"));
    let lay = Layout::new();
    assert_eq!(lay.schedule_digest(), Layout::new().schedule_digest());
    // every reserved pair row lies between the data and the proximity pair, on both commitments
    assert_eq!(lay.a_site(SC_SS, 0).unwrap(), lay.a_data_rows);
    assert_eq!(lay.a_site(SC_IO_OUT, 0).unwrap() + 2, lay.a_prox);
    assert_eq!(lay.h_site(SC_ZS, 0).unwrap() + 2, lay.h_prox);
    assert!(lay.a_site(SC_ZS, 0).is_err() && lay.h_site(SC_SS, 0).is_err());
}
