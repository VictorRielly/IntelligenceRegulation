//! Actual-FFN regression diagnostic, compiled only in unit tests.
//! Observation and extraction contain only verifier-visible inputs. Synthetic
//! witness comparisons occur in the fixture harness, after full verification.
//! This is evidence about specific groups, not a protocol repair/privacy audit.

use super::*;
use crate::export_v3::{derive_v3, V3Dims, V3Exps, V3LayerExport};
use crate::pcs::{Commitment, OpeningZk, PcsParams};
use crate::tables_v3::{int16out_member, Act16Fn};
use std::cell::RefCell;

#[path = "zk_ffn_observation_json.rs"]
mod observation_json;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) enum Role {
    W,
    A,
    H,
}

pub(super) struct Observation {
    role: Role,
    params: PcsParams,
    commitment: Commitment,
    claims: Vec<ZClaim>,
    opening: OpeningZk,
    before: Transcript,
    after: Option<Transcript>,
}

struct VerifiedObservations {
    // P1's public W uses plain PCS and is deliberately absent here.
    w: Option<Observation>,
    a: Observation,
    h: Observation,
}

thread_local! {
    // None: inactive. Some(None): armed. Some(Some(..)): fully verified.
    static OBSERVER: RefCell<Option<Option<VerifiedObservations>>> = const { RefCell::new(None) };
}

struct CaptureGuard;
impl CaptureGuard {
    fn new() -> Self {
        OBSERVER.with(|s| {
            let mut s = s.borrow_mut();
            assert!(s.is_none(), "nested diagnostic capture");
            *s = Some(None);
        });
        Self
    }
    fn take(&self) -> Option<VerifiedObservations> {
        OBSERVER.with(|s| s.borrow_mut().as_mut().unwrap().take())
    }
}
impl Drop for CaptureGuard {
    fn drop(&mut self) {
        OBSERVER.with(|s| *s.borrow_mut() = None);
    }
}

pub(super) fn capture(
    role: Role,
    params: &PcsParams,
    commitment: &Commitment,
    claims: &[ZClaim],
    opening: &OpeningZk,
    tr: &Transcript,
) -> Option<Observation> {
    OBSERVER
        .with(|s| s.borrow().is_some())
        .then(|| Observation {
            role,
            params: *params,
            commitment: commitment.clone(),
            claims: claims.to_vec(),
            opening: opening.clone(),
            before: Transcript::clone_state(tr),
            after: None,
        })
}

pub(super) fn finish(observation: &mut Option<Observation>, tr: &Transcript) {
    if let Some(o) = observation {
        o.after = Some(Transcript::clone_state(tr));
    }
}

// Called once, only after every opening has accepted. No partial publication
// if W, A or H fails, even when earlier openings have already accepted.
pub(super) fn publish(w: Option<Observation>, a: Option<Observation>, h: Option<Observation>) {
    if let Some(a) = a {
        let h = h.expect("H captured alongside A");
        assert_eq!((a.role, h.role), (Role::A, Role::H));
        assert!(same_transcript(a.after.as_ref().unwrap(), &h.before));
        if let Some(w) = &w {
            assert_eq!(w.role, Role::W);
            assert!(same_transcript(w.after.as_ref().unwrap(), &a.before));
        }
        assert!(h.after.is_some());
        OBSERVER.with(|s| {
            let mut s = s.borrow_mut();
            let slot = s.as_mut().expect("capture still armed");
            assert!(slot.is_none(), "multiple verifications in one capture");
            *slot = Some(VerifiedObservations { w, a, h });
        });
    }
}

#[derive(Clone, Debug, PartialEq)]
struct ColumnKey {
    tail: Vec<Fp2>,
    offset: usize,
    len: usize,
}
#[derive(Debug)]
struct Group {
    key: ColumnKey,
    members: Vec<usize>,
    lambdas: Vec<Fp2>,
}

#[derive(Debug)]
struct Replayed {
    groups: Vec<Group>,
    proximity_rhos: Vec<Fp2>,
}

// Deliberately independent of private PCS grouping helpers. Refuse malformed
// mappings before ordinary PCS verification (which asserts on trusted claims).
fn column_key(p: &ZPart, o: &Observation) -> Result<ColumnKey, String> {
    let n = o.params.cols();
    let len = 1usize
        .checked_shl(p.slice.log_size)
        .ok_or("slice overflow")?;
    let end = p.slice.offset.checked_add(len).ok_or("slice overflow")?;
    let capacity = o
        .commitment
        .rows
        .checked_mul(n)
        .ok_or("capacity overflow")?;
    if end > capacity || (!p.point.is_empty() && p.point.len() != p.slice.log_size as usize) {
        return Err("slice bounds/point arity".into());
    }
    if len >= n {
        if p.slice.offset % n != 0 {
            return Err("unaligned row slice".into());
        }
        let tail = if p.point.is_empty() {
            vec![]
        } else {
            p.point[p.slice.log_size as usize - o.params.log_cols as usize..].to_vec()
        };
        Ok(ColumnKey {
            tail,
            offset: 0,
            len: n,
        })
    } else {
        let offset = p.slice.offset % n;
        if offset + len > n {
            return Err("slice crosses row".into());
        }
        Ok(ColumnKey {
            tail: p.point.clone(),
            offset,
            len,
        })
    }
}

fn same_transcript(a: &Transcript, b: &Transcript) -> bool {
    // The next challenge checks the counter as well as the visible state.
    a.state() == b.state()
        && Transcript::clone_state(a).challenge_fp2() == Transcript::clone_state(b).challenge_fp2()
}

fn replay(o: &Observation, ntt: &NttTables) -> Result<Replayed, String> {
    let n = o.params.cols();
    let q = o.params.num_col_checks;
    let mut groups: Vec<Group> = Vec::new();
    for (ci, c) in o.claims.iter().enumerate() {
        let first = c.parts.first().ok_or("empty claim")?;
        let key = column_key(first, o)?;
        for p in &c.parts[1..] {
            if column_key(p, o)? != key {
                return Err("different column keys".into());
            }
        }
        if let Some(g) = groups.iter_mut().find(|g| g.key == key) {
            g.members.push(ci);
        } else {
            groups.push(Group {
                key,
                members: vec![ci],
                lambdas: vec![],
            });
        }
    }
    if groups.len() != o.opening.group_vecs.len() {
        return Err("group count".into());
    }
    let mut tr = Transcript::clone_state(&o.before);
    for g in &mut groups {
        g.lambdas = tr.challenge_fp2_vec(g.members.len());
    }
    // Actual source order: proximity coefficients BEFORE vector absorption.
    let proximity_rhos = tr.challenge_fp2_vec(o.commitment.rows);
    for (g, v) in groups.iter().zip(&o.opening.group_vecs) {
        if v.len() != n + q {
            return Err("vector length".into());
        }
        let cw = if g.key.tail.is_empty() {
            vec![Fp2::ONE; g.key.len]
        } else {
            eq_table_msb(&g.key.tail)
        };
        let got = v[g.key.offset..g.key.offset + g.key.len]
            .iter()
            .zip(cw)
            .fold(Fp2::ZERO, |a, (v, c)| a.add(v.mul(c)));
        let want = g
            .members
            .iter()
            .zip(&g.lambdas)
            .fold(Fp2::ZERO, |a, (&ci, l)| a.add(l.mul(o.claims[ci].value)));
        if got != want {
            return Err("combined public claim".into());
        }
        tr.absorb_fp2(b"pcs-vec", v);
    }
    if o.opening.prox_vec.len() != n + q {
        return Err("proximity length".into());
    }
    tr.absorb_fp2(b"pcs-prox", &o.opening.prox_vec);
    let indices = tr.challenge_indices(q, o.params.enc_cols());
    if indices != o.opening.columns.iter().map(|c| c.0).collect::<Vec<_>>() {
        return Err("sampled column indices".into());
    }
    if !same_transcript(&tr, o.after.as_ref().ok_or("not fully verified")?) {
        return Err("transcript endpoint".into());
    }
    let mut ordinary = Transcript::clone_state(&o.before);
    pcs::verify_zk(
        &o.params,
        &ZkOpts::standard(&o.params),
        &o.commitment,
        &o.claims,
        &o.opening,
        ntt,
        &mut ordinary,
    )?;
    if !same_transcript(&tr, &ordinary) {
        return Err("ordinary verifier endpoint".into());
    }
    Ok(Replayed {
        groups,
        proximity_rhos,
    })
}

#[derive(Debug, PartialEq)]
struct Disclosure {
    // One base-field functional per column; only one row means full recovery.
    row_weights: Vec<Fp>,
    values: Vec<Fp>,
}

fn determinant(a: Fp2, b: Fp2) -> Fp {
    a.c0.mul(b.c1).sub(a.c1.mul(b.c0))
}

fn eliminate_one_mask(
    claim: &ZClaim,
    lambda: Fp2,
    vector: &[Fp2],
    log_cols: u32,
) -> Result<Disclosure, String> {
    if claim.parts.len() != 2 {
        return Err("requires exactly data plus one base mask".into());
    }
    let (data, mask) = (&claim.parts[0], &claim.parts[1]);
    let n = 1usize << log_cols;
    if data.slice.log_size < log_cols
        || mask.slice.log_size != log_cols
        || data.slice.offset % n != 0
        || mask.slice.offset % n != 0
        || data.point.len() != data.slice.log_size as usize
        || mask.point.len() != log_cols as usize
        || vector.len() < n
    {
        return Err("unsupported row mapping".into());
    }
    let row_bits = (data.slice.log_size - log_cols) as usize;
    if data.point[row_bits..] != mask.point {
        return Err("mask tail mismatch".into());
    }
    let end = data.slice.offset + (1usize << data.slice.log_size);
    if (data.slice.offset..end).contains(&mask.slice.offset) {
        return Err("mask overlaps data".into());
    }
    let b = lambda.mul(mask.coef);
    if b.is_zero() {
        return Err("zero mask coefficient/lambda".into());
    }
    let weights: Vec<Fp> = eq_table_msb(&data.point[..row_bits])
        .iter()
        .map(|r| determinant(lambda.mul(data.coef).mul(*r), b))
        .collect();
    let pivot = *weights
        .iter()
        .find(|c| !c.is_zero())
        .ok_or("rank-degenerate coefficients")?;
    let inv = pivot.inv();
    Ok(Disclosure {
        row_weights: weights.into_iter().map(|c| c.mul(inv)).collect(),
        values: vector[..n]
            .iter()
            .map(|v| determinant(*v, b).mul(inv))
            .collect(),
    })
}

fn extract(
    o: &Observation,
    groups: &[Group],
    data: Slice,
    mask_row: usize,
) -> Result<Disclosure, String> {
    let matches: Vec<_> = o
        .claims
        .iter()
        .enumerate()
        .filter(|(_, c)| {
            c.parts.len() == 2
                && c.parts[0].slice.offset == data.offset
                && c.parts[0].slice.log_size == data.log_size
                && c.parts[1].slice.offset == mask_row * o.params.cols()
        })
        .collect();
    if matches.len() != 1 {
        return Err("ambiguous/missing role".into());
    }
    let (ci, claim) = matches[0];
    let (gi, group) = groups
        .iter()
        .enumerate()
        .find(|(_, g)| g.members.contains(&ci))
        .ok_or("missing group")?;
    if group.members.len() != 1 {
        return Err("not a singleton group".into());
    }
    eliminate_one_mask(
        claim,
        group.lambdas[0],
        &o.opening.group_vecs[gi],
        o.params.log_cols,
    )
}

fn fixture(t: usize, seed: u64) -> V3Witness {
    let (d, f) = (16, 16);
    let mut s = seed;
    let mut next = |m: i64| {
        s = s
            .wrapping_mul(6364136223846793005)
            .wrapping_add(1442695040888963407);
        (((s >> 33) as i64) % (2 * m + 1) - m) as i8
    };
    let x = (0..t * d).map(|_| next(127)).collect();
    let wg_t = (0..d * f).map(|_| next(4)).collect();
    let wu_t = (0..d * f).map(|_| next(4)).collect();
    let wd_t = (0..f * d).map(|_| next(4)).collect();
    let (table, table_digest) = int16out_member(Act16Fn::Silu, -3, -11).unwrap();
    let ex = V3LayerExport {
        l: 0,
        dims: V3Dims { t, d, f, layers: 1 },
        x,
        wg_t,
        wu_t,
        wd_t,
        a16: vec![],
        u16: vec![],
        h16: vec![],
        z16: vec![],
        exps: V3Exps {
            e_x: 0,
            e_g: -3,
            e_a16: -11,
            e_u16: 0,
            e_h16: 0,
            e_z16: 0,
            e_wg: 0,
            e_wu: 0,
            e_wd: 0,
        },
        shifts: (7, 0, 14, 6),
        act: Act16Fn::Silu,
        table,
        table_digest,
        digest_checks: vec![],
    };
    let w = derive_v3(&ex, t);
    assert!(w.range_ok);
    w
}

fn statement(w: &V3Witness) -> StatementV3 {
    StatementV3 {
        l: w.l,
        t_rows: w.t_rows,
        d: w.dims.d,
        f: w.dims.f,
        shifts: w.shifts,
        act: w.act,
        table: w.table,
        table_digest: w.table_digest.clone(),
    }
}

fn check_case(
    t: usize,
    privacy: ZkPrivacy,
    witness_seed: u64,
    proof_seed: Option<u64>,
) -> [u8; 32] {
    let params = if t == 2 {
        LayerParams {
            log_cols: 5,
            inv_rate: 4,
            num_col_checks: 12,
        }
    } else {
        LayerParams {
            log_cols: 8,
            inv_rate: 8,
            num_col_checks: 256,
        }
    };
    let ntt = NttTables::new(16);
    let w = fixture(t, witness_seed);
    let st = statement(&w);
    let cfg = ZkConfig {
        enabled: true,
        seed: proof_seed,
        mode: ZkStatementMode {
            privacy,
            ..Default::default()
        },
    };
    let domain = b"zk60-actual-ffn-mask-diagnostic";
    let mut prover = Transcript::new(domain);
    let proof = prove_layer_zk_v3(&w, t, &params, &ntt, &cfg, &mut prover).proof;
    let guard = CaptureGuard::new();
    let mut verifier = Transcript::new(domain);
    verify_layer_zk_v3(&st, &proof, &params, &ntt, &mut verifier, &cfg.mode).unwrap();
    assert!(same_transcript(&prover, &verifier));
    let mut observed = guard
        .take()
        .expect("full verifier published all public observations");
    assert_eq!(observed.w.is_some(), privacy == ZkPrivacy::P3);
    assert!(same_transcript(
        observed.h.after.as_ref().unwrap(),
        &verifier
    ));
    let proof_sha256 = crate::export_v3::sha256_hex(&proof.to_bytes());
    observation_json::export_if_requested(&observed, &ntt, t, privacy, &proof_sha256);
    for o in observed.w.iter().chain([&observed.a, &observed.h]) {
        let replayed = replay(o, &ntt).unwrap();
        let counts: Vec<_> = replayed.groups.iter().map(|g| g.members.len()).collect();
        assert_eq!(
            counts,
            match o.role {
                Role::W => vec![2, 1],
                Role::A => vec![7, 3, 1, 1, 6],
                Role::H => vec![3, 1, 1, 6, 1],
            }
        );
        assert_eq!(replayed.proximity_rhos.len(), o.commitment.rows);
        eprintln!("FFN_OBSERVATION privacy={privacy:?} T={t} role={:?} rows={} cols={} groups={counts:?} sampled_columns={} proof_sha256={proof_sha256}",
            o.role, o.commitment.rows, o.params.cols(), o.opening.columns.len());
    }
    let zl = ZkLayoutV3::new(t, 16, 16, &params, w.shifts, false);
    if let Some(o) = &observed.w {
        let groups = replay(o, &ntt).unwrap().groups;
        let disclosed = extract(
            o,
            &groups,
            Slice {
                offset: zl.lay.wd[0],
                log_size: zl.lay.log_wb,
            },
            zl.w_mdd[0],
        )
        .unwrap();
        let truth: Vec<_> = w.wd_t.iter().map(|v| Fp::from_i64(*v as i64)).collect();
        assert_eq!(disclosed.row_weights.len(), truth.len() / o.params.cols());
        let expected: Vec<_> = (0..o.params.cols())
            .map(|c| {
                truth
                    .chunks_exact(o.params.cols())
                    .zip(&disclosed.row_weights)
                    .fold(Fp::ZERO, |a, (r, weight)| a.add(r[c].mul(*weight)))
            })
            .collect();
        assert_eq!(disclosed.values, expected);
        assert!(truth.iter().any(|v| *v != truth[0]));
        if t == 32 {
            assert_eq!(disclosed.values, truth);
        }
        eprintln!("FFN_DIAGNOSTIC privacy={privacy:?} T={t} role=Wd-at-p6 data_rows={} disclosed_base_functionals={} full_plane_recovered={} proof_sha256={proof_sha256}",
            disclosed.row_weights.len(), o.params.cols(), t == 32);
    }
    for o in observed.w.iter_mut().chain([&mut observed.h]) {
        check_replay_controls(o, &ntt);
    }
    let o = observed.a;
    let groups = replay(&o, &ntt).unwrap().groups;
    let counts: Vec<_> = groups.iter().map(|g| g.members.len()).collect();
    assert_eq!(counts, vec![7, 3, 1, 1, 6]);
    // Truth is passed only to this comparison harness, never to the observer,
    // grouping replay or extractor. No private pads, full salt tables or RNG
    // state are read; the opening contains only already-public coordinates.
    for (name, data, mask, truth) in [
        (
            "X-at-p2",
            Slice {
                offset: zl.lay.x[0],
                log_size: zl.lay.log_t + zl.lay.log_db,
            },
            zl.a_mgu[0],
            w.x.iter()
                .map(|v| Fp::from_i64(*v as i64))
                .collect::<Vec<_>>(),
        ),
        (
            "h16-at-p5",
            Slice {
                offset: zl.lay.h16[0],
                log_size: zl.lay.log_t + zl.lay.log_fb,
            },
            zl.a_mdd[0],
            w.h16
                .iter()
                .map(|v| Fp::from_i64(*v as i64))
                .collect::<Vec<_>>(),
        ),
    ] {
        let disclosed = extract(&o, &groups, data, mask).unwrap();
        assert!(
            truth.iter().any(|v| *v != truth[0]),
            "constant fixture plane"
        );
        if t == 2 && name == "X-at-p2" {
            let other: Vec<_> = fixture(t, witness_seed + 7)
                .x
                .iter()
                .map(|v| Fp::from_i64(*v as i64))
                .collect();
            assert_ne!(disclosed.values, other);
        }
        let n = o.params.cols();
        assert_eq!(disclosed.row_weights.len(), truth.len() / n);
        let expected: Vec<_> = (0..n)
            .map(|c| {
                truth
                    .chunks_exact(n)
                    .zip(&disclosed.row_weights)
                    .fold(Fp::ZERO, |a, (r, weight)| a.add(r[c].mul(*weight)))
            })
            .collect();
        assert_eq!(disclosed.values, expected);
        if t == 2 {
            assert_eq!(disclosed.values, truth);
        } else {
            assert_eq!(disclosed.row_weights.len(), 2);
            assert!(disclosed.row_weights.iter().all(|c| !c.is_zero()));
        }
        eprintln!("FFN_DIAGNOSTIC privacy={privacy:?} T={t} rng={} role={name} groups={counts:?} data_rows={} disclosed_base_functionals={} full_plane_recovered={} proof_sha256={}",
            if proof_seed.is_some() { "fixture" } else { "fresh-os" }, disclosed.row_weights.len(),
            n, t == 2, crate::export_v3::sha256_hex(&proof.to_bytes()));
    }
    // The X-at-rho_d group contains three claims and is unsupported here.
    assert!(extract(
        &o,
        &groups,
        Slice {
            offset: zl.lay.x[0],
            log_size: zl.lay.log_t + zl.lay.log_db
        },
        zl.a_md[0]
    )
    .unwrap_err()
    .contains("singleton"));

    // Reject modified public observations; retain ordinary PCS authentication.
    let mut bad = o;
    check_replay_controls(&mut bad, &ntt);
    bad.opening.columns[0].0 ^= 1;
    assert!(replay(&bad, &ntt).unwrap_err().contains("indices"));
    bad.opening.columns[0].0 ^= 1;
    bad.opening.group_vecs.swap(2, 3);
    assert!(replay(&bad, &ntt).is_err());
    bad.opening.group_vecs.swap(2, 3);
    // Folded pad coordinates are public and authenticated too.
    bad.opening.group_vecs[2][bad.params.cols()] =
        bad.opening.group_vecs[2][bad.params.cols()].add(Fp2::ONE);
    assert!(replay(&bad, &ntt).is_err());
    bad.opening.group_vecs[2][bad.params.cols()] =
        bad.opening.group_vecs[2][bad.params.cols()].sub(Fp2::ONE);
    bad.commitment.root[0] ^= 1;
    assert!(replay(&bad, &ntt).is_err());
    bad.commitment.root[0] ^= 1;
    bad.claims.swap(10, 11);
    assert!(replay(&bad, &ntt).is_err());
    bad.claims.swap(10, 11);
    let original_before = Transcript::clone_state(&bad.before);
    bad.before.challenge_fp2();
    assert!(replay(&bad, &ntt).is_err());
    bad.before = original_before;
    bad.opening.columns[0].1[0] = bad.opening.columns[0].1[0].add(Fp::ONE);
    assert!(replay(&bad, &ntt).is_err());
    // Failed verification publishes none of W/A/H, including a late H failure
    // after W and A accepted. The guard can be reused after each failure.
    let mut bad_proof = proof;
    if privacy == ZkPrivacy::P3 {
        bad_proof.w_open_zk.columns[0].1[0] = bad_proof.w_open_zk.columns[0].1[0].add(Fp::ONE);
        let err = verify_layer_zk_v3(
            &st,
            &bad_proof,
            &params,
            &ntt,
            &mut Transcript::new(domain),
            &cfg.mode,
        )
        .unwrap_err();
        assert!(err.starts_with("W:"), "{err}");
        assert!(guard.take().is_none());
        bad_proof.w_open_zk.columns[0].1[0] = bad_proof.w_open_zk.columns[0].1[0].sub(Fp::ONE);
    }
    bad_proof.a_open.columns[0].1[0] = bad_proof.a_open.columns[0].1[0].add(Fp::ONE);
    let err = verify_layer_zk_v3(
        &st,
        &bad_proof,
        &params,
        &ntt,
        &mut Transcript::new(domain),
        &cfg.mode,
    )
    .unwrap_err();
    assert!(err.starts_with("A:"), "{err}");
    assert!(guard.take().is_none());
    bad_proof.a_open.columns[0].1[0] = bad_proof.a_open.columns[0].1[0].sub(Fp::ONE);
    bad_proof.h_open.columns[0].1[0] = bad_proof.h_open.columns[0].1[0].add(Fp::ONE);
    let err = verify_layer_zk_v3(
        &st,
        &bad_proof,
        &params,
        &ntt,
        &mut Transcript::new(domain),
        &cfg.mode,
    )
    .unwrap_err();
    assert!(err.starts_with("H:"), "{err}");
    assert!(guard.take().is_none());
    bad_proof.h_open.columns[0].1[0] = bad_proof.h_open.columns[0].1[0].sub(Fp::ONE);
    // Unarmed verification remains inert (no observer copies).
    drop(guard);
    verify_layer_zk_v3(
        &st,
        &bad_proof,
        &params,
        &ntt,
        &mut Transcript::new(domain),
        &cfg.mode,
    )
    .unwrap();
    assert!(OBSERVER.with(|s| s.borrow().is_none()));
    assert!(capture(
        Role::A,
        &bad.params,
        &bad.commitment,
        &bad.claims,
        &bad.opening,
        &bad.before
    )
    .is_none());
    bad.commitment.root
}

fn check_replay_controls(o: &mut Observation, ntt: &NttTables) {
    let group = o.opening.group_vecs.pop().unwrap();
    assert!(replay(o, ntt).unwrap_err().contains("group count"));
    o.opening.group_vecs.push(group);
    let element = o.opening.group_vecs[0].pop().unwrap();
    assert!(replay(o, ntt).unwrap_err().contains("vector length"));
    o.opening.group_vecs[0].push(element);
    let element = o.opening.prox_vec.pop().unwrap();
    assert!(replay(o, ntt).unwrap_err().contains("proximity length"));
    o.opening.prox_vec.push(element);
    let after = o.after.take().unwrap();
    assert!(replay(o, ntt).unwrap_err().contains("not fully verified"));
    o.after = Some(Transcript::clone_state(&after));
    o.after.as_mut().unwrap().challenge_fp2();
    assert!(replay(o, ntt).unwrap_err().contains("transcript endpoint"));
    o.after = Some(after);
    o.commitment.root[0] ^= 1;
    assert!(replay(o, ntt).is_err());
    o.commitment.root[0] ^= 1;
    o.opening.columns[0].1[0] = o.opening.columns[0].1[0].add(Fp::ONE);
    assert!(replay(o, ntt).is_err());
    o.opening.columns[0].1[0] = o.opening.columns[0].1[0].sub(Fp::ONE);
    let actual = replay(o, ntt).unwrap();
    // Pin the actual order: drawing proximity after group absorption changes
    // both the public challenges and endpoint. Older PCS comments said this.
    let mut wrong = Transcript::clone_state(&o.before);
    for g in &actual.groups {
        wrong.challenge_fp2_vec(g.members.len());
    }
    for v in &o.opening.group_vecs {
        wrong.absorb_fp2(b"pcs-vec", v);
    }
    assert_ne!(
        wrong.challenge_fp2_vec(o.commitment.rows),
        actual.proximity_rhos
    );
    wrong.absorb_fp2(b"pcs-prox", &o.opening.prox_vec);
    wrong.challenge_indices(o.params.num_col_checks, o.params.enc_cols());
    assert!(!same_transcript(&wrong, o.after.as_ref().unwrap()));
}

#[test]
fn capture_guard_resets_on_unwind_and_rejects_nested_capture() {
    let result = std::panic::catch_unwind(|| {
        let _guard = CaptureGuard::new();
        let _nested = CaptureGuard::new();
    });
    assert!(result.is_err());
    assert!(OBSERVER.with(|s| s.borrow().is_none()));
    let guard = CaptureGuard::new();
    assert!(guard.take().is_none());
}

#[test]
fn actual_ffn_seeded_singleton_rows_are_recovered_in_p1_and_p3() {
    for privacy in [ZkPrivacy::P1, ZkPrivacy::P3] {
        for seed in [1, 2] {
            check_case(2, privacy, seed, Some(seed + 100));
        }
    }
}

#[test]
#[cfg(unix)]
fn actual_ffn_fresh_os_singleton_rows_are_recovered_without_resampling() {
    for privacy in [ZkPrivacy::P1, ZkPrivacy::P3] {
        assert_ne!(
            check_case(2, privacy, 1, None),
            check_case(2, privacy, 1, None)
        );
    }
}

#[test]
fn actual_ffn_t32_recovers_one_functional_per_column_of_two_row_planes() {
    for privacy in [ZkPrivacy::P1, ZkPrivacy::P3] {
        check_case(32, privacy, 1, Some(101));
        check_case(32, privacy, 1, None);
    }
}

#[test]
fn diagnostic_refuses_degenerate_and_paired_mask_controls() {
    let point = vec![Fp2::U; 2];
    let data = ZPart {
        slice: Slice {
            offset: 0,
            log_size: 2,
        },
        coef: Fp2::ONE,
        point: point.clone(),
    };
    let mask = ZPart {
        slice: Slice {
            offset: 4,
            log_size: 2,
        },
        coef: Fp2::U,
        point,
    };
    let mut c = ZClaim {
        parts: vec![data, mask],
        value: Fp2::ZERO,
    };
    let v = vec![Fp2::ZERO; 4];
    assert!(eliminate_one_mask(&c, Fp2::ZERO, &v, 2)
        .unwrap_err()
        .contains("zero"));
    c.parts[1].coef = Fp2::ONE;
    assert!(eliminate_one_mask(&c, Fp2::ONE, &v, 2)
        .unwrap_err()
        .contains("rank-degenerate"));
    c.parts[1].coef = Fp2::ZERO;
    assert!(eliminate_one_mask(&c, Fp2::ONE, &v, 2)
        .unwrap_err()
        .contains("zero"));
    c.parts[1].coef = Fp2::U;
    let mut bad_tail = c.clone();
    bad_tail.parts[1].point[0] = Fp2::ONE;
    assert!(eliminate_one_mask(&bad_tail, Fp2::ONE, &v, 2)
        .unwrap_err()
        .contains("tail mismatch"));
    let mut overlap = c.clone();
    overlap.parts[1].slice.offset = 0;
    assert!(eliminate_one_mask(&overlap, Fp2::ONE, &v, 2)
        .unwrap_err()
        .contains("overlaps"));
    let mut second_mask = c.parts[1].clone();
    second_mask.slice.offset = 8;
    second_mask.coef = Fp2::ONE;
    c.parts.push(second_mask);
    assert!(eliminate_one_mask(&c, Fp2::ONE, &v, 2)
        .unwrap_err()
        .contains("exactly"));
    // Two independent Fp2 directions span both base coordinates. This controls
    // this local eliminator only, not joint privacy of the real FFN protocol.
    assert!(!determinant(c.parts[1].coef, c.parts[2].coef).is_zero());
    c.parts.pop();
    c.parts[0].slice.log_size = 3;
    assert!(eliminate_one_mask(&c, Fp2::ONE, &v, 2)
        .unwrap_err()
        .contains("mapping"));
}
