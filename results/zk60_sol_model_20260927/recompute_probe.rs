//! Test-only drop-and-recompute opening prototype; no production path change.
use super::*;
use crate::hashtag::HashTag;
use crate::mle::eval_mle_base;
use crate::rng::ZkRng;
use crate::transcript::Transcript;

fn open_recomputed(cmz: &CommittedZk, claims: &[ZClaim], ntt: &NttTables,
                   tr: &mut Transcript) -> OpeningZk {
    let cm = &cmz.cm;
    let rows = cm.rows;
    let groups = group_zclaims(claims, rows, cm.params.log_cols);
    let (rhos, _) = zk_rhos(&groups, rows, tr);
    assert_mask_sites(cmz, &rhos);
    let mut vecs = fold_rows_multi_zk(cmz, &rhos);
    let prox_vec = vecs.pop().unwrap();
    for v in &vecs { tr.absorb_fp2(b"pcs-vec", v); }
    tr.absorb_fp2(b"pcs-prox", &prox_vec);
    let idx = tr.challenge_indices(cm.params.num_col_checks, cm.params.enc_cols());
    let (n, nn, q) = (cm.params.cols(), cm.params.enc_cols(), cmz.zk.q_pad);
    let mut columns: Vec<Vec<Fp>> = idx.iter().map(|_| Vec::with_capacity(rows)).collect();
    let pows = coset_powers(cmz.zk.coset, nn);
    let mut encoded_row = vec![Fp::ZERO; nn];
    for row in 0..rows {
        encode_row_zk(ntt, &cmz.data[row * n..(row + 1) * n],
            &cmz.pads[row * q..(row + 1) * q], &pows, &mut encoded_row);
        for (out, &j) in columns.iter_mut().zip(&idx) { out.push(encoded_row[j]); }
    }
    let columns = idx.iter().zip(columns).map(|(&j, col)|
        (j, col, cmz.salts[j], cm.tree.path(j))).collect();
    OpeningZk { group_vecs: vecs, prox_vec, columns }
}

/// Oracle construction with bounded encoded rows. Production must review
/// scheduling and expose an owning compact store before using this path.
fn stream_commit(params: &PcsParams, data: Vec<Fp>, ntt: &NttTables,
                 zk: &ZkOpts, rng: &mut ZkRng, tag: &HashTag, chunk_rows: usize)
                 -> (CommittedZk, Vec<Digest>, usize) {
    let n = params.cols();
    let nn = params.enc_cols();
    let rows = data.len() / n;
    let q = zk.q_pad;
    assert!(rows > 0 && data.len() == rows * n && chunk_rows > 0);
    let pads = rng.fp_vec(rows * q);
    let salts: Vec<[u8; 32]> = (0..nn).map(|_| rng.bytes32()).collect();
    let pows = coset_powers(zk.coset, nn);
    let mut hashers: Vec<blake3::Hasher> = (0..nn)
        .map(|_| crate::hashtag::hasher(tag.column_key())).collect();
    let held_rows = chunk_rows.min(rows);
    let mut encoded_chunk = vec![Fp::ZERO; held_rows * nn];
    for base in (0..rows).step_by(held_rows) {
        let count = (rows - base).min(held_rows);
        for k in 0..count {
            let row = base + k;
            encode_row_zk(ntt, &data[row*n..(row+1)*n],
                &pads[row*q..(row+1)*q], &pows,
                &mut encoded_chunk[k*nn..(k+1)*nn]);
        }
        for k in 0..count {
            for (h, v) in hashers.iter_mut().zip(&encoded_chunk[k*nn..(k+1)*nn]) {
                h.update(&v.to_bytes());
            }
        }
    }
    let leaves: Vec<Digest> = hashers.iter().map(|h| *h.finalize().as_bytes()).collect();
    let salted: Vec<Digest> = leaves.iter().zip(&salts)
        .map(|(leaf, salt)| salt_leaf_keyed(leaf, salt, tag.leaf_key())).collect();
    let tree = MerkleTree::build_keyed(salted, tag.node_key());
    let peak_encoded_buffer_bytes = encoded_chunk.len() * 8;
    let cmz = CommittedZk {
        cm: Committed { params: *params, rows,
            store: Store::Host { encoded: Vec::new() }, tree },
        zk: *zk, data, pads, salts,
        mask_rows: Vec::new(), prox_mask_row: None,
    };
    (cmz, leaves, peak_encoded_buffer_bytes)
}

fn opening_claim(cmz: &CommittedZk) -> Vec<ZClaim> {
    let n = cmz.cm.params.cols();
    let lg = cmz.cm.params.log_cols as usize;
    let point: Vec<Fp2> = (0..lg).map(|i| Fp2::from_u64((i + 3) as u64)).collect();
    let e = Fp2::from_u64(17);
    let v0 = eval_mle_base(&cmz.data[..n], &point);
    let v1 = eval_mle_base(&cmz.data[n..2*n], &point);
    vec![ZClaim { parts: vec![
        ZPart { slice: Slice { offset: 0, log_size: cmz.cm.params.log_cols },
            coef: Fp2::ONE.sub(e), point: point.clone() },
        ZPart { slice: Slice { offset: n, log_size: cmz.cm.params.log_cols },
            coef: e, point },
    ], value: Fp2::ONE.sub(e).mul(v0).add(e.mul(v1)) }]
}

#[test]
fn streamed_rows_match_every_leaf_root_opening_and_rng() {
    // q=16 > n=4 exercises the encoder's overlapping pad-coefficient arm.
    // The last case draws enough columns from 32 to force repeated indices.
    let cases = [(2u32, 8usize, 7usize, 2usize, 1usize),
                 (2, 8, 16, 5, 3), (4, 4, 4, 3, 2),
                 (5, 2, 7, 9, 4)];
    let mut saw_duplicate = false;
    for tagged in [false, true] {
        let tag = if tagged { HashTag::for_profile("streaming-row-probe/1") }
                  else { HashTag::legacy() };
        for (lc, ir, q, rows, chunk) in cases {
            let params = PcsParams { log_cols: lc, inv_rate: ir,
                                     num_col_checks: q.min(16) };
            let zk = ZkOpts { q_pad: q, coset: Fp::new(7) };
            let ntt = NttTables::new(lc + ir.trailing_zeros());
            let n = params.cols();
            let mut data: Vec<Fp> = (0..rows*n)
                .map(|i| Fp::from_i64((i as i64 * 17 % 101) - 50)).collect();
            if rows >= 3 {
                let mut mask_rng = ZkRng::new(771 + rows as u64, b"streaming-row-private-mask-fixture");
                for row in [1usize, 2] {
                    for v in &mut data[row*n..(row+1)*n] { *v = mask_rng.fp(); }
                }
            }
            let mut a_rng = ZkRng::new(9917 + rows as u64, b"streaming-row-test");
            let mut b_rng = ZkRng::new(9917 + rows as u64, b"streaming-row-test");
            let mut full = commit_zk_owned_with_tag(&Cpu, &params, data.clone(),
                &ntt, &zk, &mut a_rng, &tag);
            let (mut streamed, leaves, peak) = stream_commit(&params, data,
                &ntt, &zk, &mut b_rng, &tag, chunk);
            assert!(peak <= chunk * params.enc_cols() * 8);
            println!("STREAM_CASE tagged={tagged} log_cols={lc} rate={ir} q={q} rows={rows} chunk={chunk} hasher_state_bytes={} encoded_chunk_bytes={peak} pads_bytes={} salts_bytes={}",
                params.enc_cols() * std::mem::size_of::<blake3::Hasher>(),
                streamed.pads.len() * 8, streamed.salts.len() * 32);
            assert_eq!(a_rng.bytes32(), b_rng.bytes32(), "RNG continuation");
            assert_eq!(full.pads, streamed.pads);
            assert_eq!(full.salts, streamed.salts);
            let encoded = match &full.cm.store {
                Store::Host { encoded } => encoded,
                Store::Device(_) => panic!("CPU oracle offered an external store"),
            };
            assert_eq!(leaves, hash_columns_keyed(encoded, rows, params.enc_cols(), tag.column_key()),
                       "every unsalted column leaf");
            assert_eq!(full.cm.tree.levels, streamed.cm.tree.levels, "every salted leaf and node");
            assert_eq!(full.commitment().root, streamed.commitment().root);
            if rows < 3 { continue; }
            full.mask_rows = vec![1]; full.prox_mask_row = Some(2);
            streamed.mask_rows = vec![1]; streamed.prox_mask_row = Some(2);
            let claims = opening_claim(&full);
            let mut at = if tagged { Transcript::new_tagged(b"streamed-open", [43; 32]) }
                         else { Transcript::new(b"streamed-open") };
            let mut bt = if tagged { Transcript::new_tagged(b"streamed-open", [43; 32]) }
                         else { Transcript::new(b"streamed-open") };
            let ordinary = open_zk(&full, &claims, &mut at);
            let compact = open_recomputed(&streamed, &claims, &ntt, &mut bt);
            let mut ob = Vec::new(); let mut cb = Vec::new();
            ordinary.write_bytes(&mut ob); compact.write_bytes(&mut cb);
            assert_eq!(ob, cb, "complete opening bytes");
            assert_eq!(at.state(), bt.state(), "transcript state");
            assert_eq!(at.challenge_fp2(), bt.challenge_fp2(), "next challenge");
            let mut seen = std::collections::HashSet::new();
            saw_duplicate |= compact.columns.iter().any(|(j, _, _, _)| !seen.insert(*j));
            let mut vt = if tagged { Transcript::new_tagged(b"streamed-open", [43; 32]) }
                         else { Transcript::new(b"streamed-open") };
            let verdict = if tagged {
                verify_zk_tagged(&params, &zk, &streamed.commitment(), &claims,
                    &compact, &ntt, &mut vt, &tag)
            } else {
                verify_zk(&params, &zk, &streamed.commitment(), &claims,
                    &compact, &ntt, &mut vt)
            };
            verdict.unwrap();
            vt.challenge_fp2();
            assert_eq!(vt.state(), bt.state(), "verifier transcript continuation");
            // A malformed sampled column and salt must both be refused.
            let mut bad = compact.clone(); bad.columns[0].1[0] = bad.columns[0].1[0].add(Fp::ONE);
            let mut bad_tr = if tagged { Transcript::new_tagged(b"streamed-open", [43; 32]) }
                             else { Transcript::new(b"streamed-open") };
            let bad_result = if tagged {
                verify_zk_tagged(&params, &zk, &streamed.commitment(), &claims,
                    &bad, &ntt, &mut bad_tr, &tag)
            } else {
                verify_zk(&params, &zk, &streamed.commitment(), &claims,
                    &bad, &ntt, &mut bad_tr)
            };
            assert!(bad_result.is_err());
            let mut bad = compact.clone(); bad.columns[0].3[0][0] ^= 1;
            let mut bad_tr = if tagged { Transcript::new_tagged(b"streamed-open", [43; 32]) }
                             else { Transcript::new(b"streamed-open") };
            let bad_result = if tagged {
                verify_zk_tagged(&params, &zk, &streamed.commitment(), &claims,
                    &bad, &ntt, &mut bad_tr, &tag)
            } else {
                verify_zk(&params, &zk, &streamed.commitment(), &claims,
                    &bad, &ntt, &mut bad_tr)
            };
            assert!(bad_result.is_err());
            let mut bad = compact.clone(); bad.columns[0].2[0] ^= 1;
            let mut bad_tr = if tagged { Transcript::new_tagged(b"streamed-open", [43; 32]) }
                             else { Transcript::new(b"streamed-open") };
            let bad_result = if tagged {
                verify_zk_tagged(&params, &zk, &streamed.commitment(), &claims,
                    &bad, &ntt, &mut bad_tr, &tag)
            } else {
                verify_zk(&params, &zk, &streamed.commitment(), &claims,
                    &bad, &ntt, &mut bad_tr)
            };
            assert!(bad_result.is_err());
        }
    }
    assert!(saw_duplicate, "the fixtures did not exercise repeated queried columns");
}

#[test]
fn dropping_encoded_after_root_preserves_tagged_opening_bytes() {
    println!("blake3_hasher_bytes={}", std::mem::size_of::<blake3::Hasher>());
    let p = PcsParams { log_cols: 4, inv_rate: 4, num_col_checks: 4 };
    let zk = ZkOpts::standard(&p);
    let ntt = NttTables::new(6);
    let tag = HashTag::for_profile("recompute-probe/1");
    let mut rng = ZkRng::new(20260927, b"recompute-probe");
    let n = p.cols();
    let mut data = vec![Fp::ZERO; 4 * n];
    for i in 0..n { data[i] = Fp::from_i64(i as i64 - 7); }
    for row in [1usize, 2] { for i in 0..n { data[row * n + i] = rng.fp(); } }
    let mut cmz = commit_zk_owned_with_tag(&Cpu, &p, data, &ntt, &zk, &mut rng, &tag);
    cmz.mask_rows = vec![1];
    cmz.prox_mask_row = Some(2);
    let pt: Vec<Fp2> = (0..4).map(|i| Fp2::from_u64((i + 3) as u64)).collect();
    let e = Fp2::from_u64(17);
    let v0 = eval_mle_base(&cmz.data[..n], &pt);
    let v1 = eval_mle_base(&cmz.data[n..2*n], &pt);
    let claims = vec![ZClaim { parts: vec![
        ZPart { slice: Slice { offset: 0, log_size: 4 }, coef: Fp2::ONE.sub(e), point: pt.clone() },
        ZPart { slice: Slice { offset: n, log_size: 4 }, coef: e, point: pt },
    ], value: Fp2::ONE.sub(e).mul(v0).add(e.mul(v1)) }];
    let root = cmz.commitment();
    let mut ordinary_tr = Transcript::new_tagged(b"pcs-recompute-probe", [77; 32]);
    let ordinary = open_zk(&cmz, &claims, &mut ordinary_tr);
    match &mut cmz.cm.store {
        Store::Host { encoded } => drop(std::mem::take(encoded)),
        Store::Device(_) => panic!("CPU test unexpectedly used external store"),
    }
    let mut compact_tr = Transcript::new_tagged(b"pcs-recompute-probe", [77; 32]);
    let compact = open_recomputed(&cmz, &claims, &ntt, &mut compact_tr);
    let mut a = Vec::new();
    let mut b = Vec::new();
    ordinary.write_bytes(&mut a);
    compact.write_bytes(&mut b);
    assert_eq!(a, b);
    assert_eq!(ordinary_tr.state(), compact_tr.state());
    assert_eq!(ordinary_tr.challenge_fp2(), compact_tr.challenge_fp2());
    let mut verify_tr = Transcript::new_tagged(b"pcs-recompute-probe", [77; 32]);
    verify_zk_tagged(&p, &zk, &root, &claims, &compact, &ntt, &mut verify_tr, &tag).unwrap();
    verify_tr.challenge_fp2();
    assert_eq!(verify_tr.state(), compact_tr.state());
    // Test-only repeated openings: a changed retained source must not open
    // against the old root. Production boundary owners remain consuming.
    cmz.data[0] = cmz.data[0].add(Fp::ONE);
    let mut bad_tr = Transcript::new_tagged(b"pcs-recompute-probe", [77; 32]);
    let bad_data = open_recomputed(&cmz, &claims, &ntt, &mut bad_tr);
    let mut check = Transcript::new_tagged(b"pcs-recompute-probe", [77; 32]);
    assert!(verify_zk_tagged(&p, &zk, &root, &claims, &bad_data, &ntt, &mut check, &tag).is_err());
    cmz.data[0] = cmz.data[0].sub(Fp::ONE);
    cmz.pads[0] = cmz.pads[0].add(Fp::ONE);
    let mut bad_tr = Transcript::new_tagged(b"pcs-recompute-probe", [77; 32]);
    let bad_pad = open_recomputed(&cmz, &claims, &ntt, &mut bad_tr);
    let mut check = Transcript::new_tagged(b"pcs-recompute-probe", [77; 32]);
    assert!(verify_zk_tagged(&p, &zk, &root, &claims, &bad_pad, &ntt, &mut check, &tag).is_err());
}
