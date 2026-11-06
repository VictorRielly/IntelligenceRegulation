//! **D63 step L5 (Lean lane, 2026-11-06): the agreement corpus between the Rust primitives and the executable Lean
//! verifier's foundation** (`formal/ZK60Formal/ExecField.lean`, `ExecBlake3.lean`, `ExecTranscript.lean`,
//! `ExecMerkle.lean`; the checker is `formal/ZK60Formal/L5Check.lean`).
//!
//! TEST ONLY: an integration test, so no production source changes and nothing in the crate calls it. It records,
//! from the crate's own code paths: field operations (`Fp`, `Fp2`, the byte encodings), BLAKE3 digests in the three
//! modes (`blake3::hash`, `Hasher::new_keyed`, `derive_key`, including the four hash-tag keys of two profiles),
//! transcript runs (every absorb and challenge kind, with the state after each), Merkle trees and paths (honest and
//! tampered), and whole tagged PCS openings made by `commit_zk_owned_with_tag` / `open_zk` and accepted by
//! `verify_zk_tagged` (their Merkle openings, and the transcript the verifier ran, which the Lean side replays).
//! All data are public synthetic values (fixed seeds, public profile strings); no key, salt or opening of any
//! production commitment is involved.
//!
//! Output: one record per line, space-separated, decimal numbers and lowercase hex bytes (`-` for an empty or absent
//! field). Run with `LEAN_L5_CORPUS=<path> cargo test --release --offline --locked --test lean_l5_export`; without
//! the variable the test only builds the corpus and checks its own records against the crate.
use std::fmt::Write as _;
use zkp_core::field::{Fp, Fp2, P};
use zkp_core::hashtag::{HashTag, CTX_COLUMN, CTX_LEAF, CTX_NODE, CTX_TRANSCRIPT};
use zkp_core::merkle::{hash_pair_keyed, MerkleTree};
use zkp_core::mle::eval_mle_base;
use zkp_core::ntt::NttTables;
use zkp_core::pcs::{self, Cpu, PcsParams, Slice, ZClaim, ZPart, ZkOpts};
use zkp_core::rng::ZkRng;
use zkp_core::transcript::Transcript;

const RUNG_G: &str = "hashline-zk-mr1/private-block-rung-g-t24-dev/1";
const M125: &str = "hashline-zk-mr1/private-block-m125/1";

fn hex(b: &[u8]) -> String {
    if b.is_empty() {
        return "-".into();
    }
    b.iter().map(|x| format!("{x:02x}")).collect()
}

/// xorshift64* (the generator `field.rs`'s tests use)
struct Rng(u64);
impl Rng {
    fn next(&mut self) -> u64 {
        let mut x = self.0;
        x ^= x >> 12;
        x ^= x << 25;
        x ^= x >> 27;
        self.0 = x;
        x.wrapping_mul(0x2545F4914F6CDD1D)
    }
}

/// `gen:<seed>:<len>` data, recomputed by the Lean checker (`genBytes`)
fn gen_bytes(seed: u64, len: usize) -> Vec<u8> {
    (0..len as u64).map(|i| (i.wrapping_mul(0x9E37_79B9_7F4A_7C15).wrapping_add(seed.wrapping_mul(0xD1B5_4A32_D192_ED03)) >> 56) as u8).collect()
}

/// `fgen:<n>` Fp2 vectors (the A14 test's), recomputed by the Lean checker (`genFp2`)
fn gen_fp2(n: usize) -> Vec<Fp2> {
    (0..n as u64).map(|i| Fp2::new(Fp::new(i.wrapping_mul(0x9e37_79b9_7f4a_7c15)), Fp::new(i ^ 0xdead_beef))).collect()
}

fn fp2_csv(v: &[Fp2]) -> String {
    if v.is_empty() {
        return "-".into();
    }
    v.iter().map(|x| format!("{},{}", x.c0.0, x.c1.0)).collect::<Vec<_>>().join(",")
}

fn fp_csv(v: &[Fp]) -> String {
    if v.is_empty() {
        return "-".into();
    }
    v.iter().map(|x| x.0.to_string()).collect::<Vec<_>>().join(",")
}

fn path_csv(p: &[[u8; 32]]) -> String {
    if p.is_empty() {
        return "-".into();
    }
    p.iter().map(|d| hex(d)).collect::<Vec<_>>().join(",")
}

fn keyed(key: Option<&[u8; 32]>, data: &[u8]) -> [u8; 32] {
    let mut h = zkp_core::hashtag::hasher(key);
    h.update(data);
    *h.finalize().as_bytes()
}

/// `hash_column_keyed` (private in `pcs.rs`) through the public tiled path with one column
fn column_digest(col: &[Fp], key: Option<&[u8; 32]>) -> [u8; 32] {
    pcs::hash_columns_keyed(col, col.len(), 1, key)[0]
}

fn key_or_dash(k: Option<&[u8; 32]>) -> String {
    k.map(|k| hex(k)).unwrap_or_else(|| "-".into())
}

struct Corpus {
    out: String,
    n: usize,
}
impl Corpus {
    fn line(&mut self, s: String) {
        self.out.push_str(&s);
        self.out.push('\n');
        self.n += 1;
    }
}

const EPS: u64 = 0xFFFF_FFFF;

fn field_records(c: &mut Corpus) {
    let mut r = Rng(0x15_d63_15_d63);
    let edges: Vec<u64> = vec![0, 1, 2, 3, 7, P - 1, P - 2, P - 3, EPS, EPS + 1, EPS - 1, 1 << 32, (1 << 32) + 1, 1 << 63, (1 << 63) - 1, P - EPS, P - (1 << 32), 0x8000_0000_8000_0000 % P, 0xFFFF_FFFE_FFFF_FFFF];
    let mut canon: Vec<u64> = edges.clone();
    for _ in 0..240 {
        canon.push(r.next() % P);
    }
    // binary ops on canonical inputs: edges x edges, then random pairs
    let mut pairs: Vec<(u64, u64)> = Vec::new();
    for &a in &edges {
        for &b in &edges {
            pairs.push((a, b));
        }
    }
    for i in 0..canon.len() {
        pairs.push((canon[i], canon[(i * 7 + 3) % canon.len()]));
    }
    for &(a, b) in &pairs {
        c.line(format!("FP add {a} {b} {}", Fp(a).add(Fp(b)).0));
        c.line(format!("FP sub {a} {b} {}", Fp(a).sub(Fp(b)).0));
        c.line(format!("FP mul {a} {b} {}", Fp(a).mul(Fp(b)).0));
    }
    for &a in &canon {
        c.line(format!("FP neg {a} {}", Fp(a).neg().0));
        if a != 0 {
            c.line(format!("FP inv {a} {}", Fp(a).inv().0));
        }
        let e = r.next();
        c.line(format!("FP pow {a} {e} {}", Fp(a).pow(e).0));
        c.line(format!("BY fp {a} {}", hex(&Fp(a).to_bytes())));
    }
    // `mul` on NON-canonical words too (the Lean theorem needs no canonical input)
    for _ in 0..40 {
        let (a, b) = (r.next(), r.next());
        c.line(format!("FP mul {a} {b} {}", Fp(a).mul(Fp(b)).0));
    }
    // `new` on any word, `from_u128` on every width
    let mut words: Vec<u64> = vec![0, 1, P - 1, P, P + 1, u64::MAX, u64::MAX - 1, EPS, 2 * EPS];
    for _ in 0..60 {
        words.push(r.next());
    }
    for &w in &words {
        c.line(format!("FP new {w} {}", Fp::new(w).0));
    }
    let p = P as u128;
    let mut wide: Vec<u128> = vec![0, 1, p - 1, p, p + 1, 2 * p, u64::MAX as u128, 1u128 << 64, (1u128 << 96) - 1, 1u128 << 96, (1u128 << 96) + 1, u128::MAX, u128::MAX - 1, u128::MAX / p * p, u128::MAX / p * p - 1];
    for i in 0..129u32 {
        let v = (((r.next() as u128) << 64) | r.next() as u128) >> i.min(127);
        wide.push(v);
    }
    for &v in &wide {
        c.line(format!("FP u128 {} {} {}", (v >> 64) as u64, v as u64, Fp::from_u128(v).0));
    }
    // the extension field
    let fp2s: Vec<Fp2> = (0..160).map(|i| {
        if i < 16 {
            Fp2::new(Fp(edges[i % edges.len()]), Fp(edges[(i * 5 + 1) % edges.len()]))
        } else {
            Fp2::new(Fp(r.next() % P), Fp(r.next() % P))
        }
    }).collect();
    for i in 0..fp2s.len() {
        let (a, b) = (fp2s[i], fp2s[(i * 11 + 5) % fp2s.len()]);
        let s = |x: Fp2| format!("{} {}", x.c0.0, x.c1.0);
        c.line(format!("F2 add {} {} {}", s(a), s(b), s(a.add(b))));
        c.line(format!("F2 sub {} {} {}", s(a), s(b), s(a.sub(b))));
        c.line(format!("F2 mul {} {} {}", s(a), s(b), s(a.mul(b))));
        c.line(format!("F2 neg {} {}", s(a), s(a.neg())));
        c.line(format!("F2 mulbase {} {} {}", s(a), b.c0.0, s(a.mul_base(b.c0))));
        if !a.is_zero() {
            c.line(format!("F2 inv {} {}", s(a), s(a.inv())));
        }
        c.line(format!("BY fp2 {} {}", s(a), hex(&a.to_bytes())));
    }
    // `from_bytes` of arbitrary 16 bytes (non-canonical words included)
    for i in 0..24u64 {
        let mut b = gen_bytes(1000 + i, 16);
        if i % 4 == 0 {
            b[..8].copy_from_slice(&(P + i).to_le_bytes());
        }
        if i % 4 == 1 {
            b[8..].copy_from_slice(&u64::MAX.to_le_bytes());
        }
        let x = Fp2::from_bytes(&b);
        c.line(format!("BY fp2from {} {} {}", hex(&b), x.c0.0, x.c1.0));
    }
}

fn blake3_records(c: &mut Corpus) {
    let lens = [0usize, 1, 2, 31, 32, 33, 47, 48, 63, 64, 65, 127, 128, 129, 1023, 1024, 1025, 1088, 2047, 2048, 2049, 3071, 3072, 3073, 4095, 4096, 4097, 5121, 8191, 8192, 8193, 16384, 16389, 31744, 65536, 102400, 266_624];
    let key = *blake3::hash(b"lean l5 corpus key").as_bytes();
    for (i, &len) in lens.iter().enumerate() {
        let seed = 7 + i as u64;
        let d = gen_bytes(seed, len);
        c.line(format!("B3 hash - gen:{seed}:{len} {}", hex(blake3::hash(&d).as_bytes())));
        c.line(format!("B3 keyed {} gen:{seed}:{len} {}", hex(&key), hex(&keyed(Some(&key), &d))));
        let ctx = "lean l5 corpus derive context";
        c.line(format!("B3 derive {} gen:{seed}:{len} {}", hex(ctx.as_bytes()), hex(&blake3::derive_key(ctx, &d))));
    }
    // the four hash-tag keys of the two pinned profiles (`hashtag.rs`), as `derive_key` records
    for prof in [RUNG_G, M125] {
        for ctx in [CTX_TRANSCRIPT, CTX_COLUMN, CTX_LEAF, CTX_NODE] {
            c.line(format!("B3 derive {} h:{} {}", hex(ctx.as_bytes()), hex(prof.as_bytes()), hex(&blake3::derive_key(ctx, prof.as_bytes()))));
        }
    }
}

/// A transcript run with the state after every operation.
fn transcript_records(c: &mut Corpus) {
    let st = |t: &Transcript| hex(&t.state());
    for (mode, domain) in [(0, "hashline-zk-mr1/private-block-t32-poc/1"), (1, RUNG_G), (2, M125)] {
        let mut t = if mode == 0 {
            c.line(format!("TR new {}", hex(domain.as_bytes())));
            Transcript::new(domain.as_bytes())
        } else {
            let k = *HashTag::for_profile(domain).transcript_key().unwrap();
            c.line(format!("TR tagged {} {}", hex(domain.as_bytes()), hex(&k)));
            Transcript::new_tagged(domain.as_bytes(), k)
        };
        c.line(format!("TS {}", st(&t)));
        // absorbs of every kind, real labels, data of every length class
        let absorbs: Vec<(&[u8], usize)> = vec![(b"schedule", 32), (b"expected-io", 0), (b"root", 32), (b"x", 1), (b"", 5), (b"calibration", 1025), (b"a-label-of-some-length-0123456789", 4097)];
        for (i, &(label, len)) in absorbs.iter().enumerate() {
            let schedule = i == 0;
            let d = if schedule { vec![7u8; 32] } else { gen_bytes(100 + i as u64, len) };
            t.absorb(label, &d);
            let spec = if schedule { format!("h:{}", hex(&d)) } else { format!("gen:{}:{len}", 100 + i as u64) };
            c.line(format!("TA {} {spec} {}", hex(label), st(&t)));
        }
        t.absorb_u64(b"log-cols", 10);
        c.line(format!("TU {} 10 {}", hex(b"log-cols"), st(&t)));
        t.absorb_u64(b"rows", u64::MAX);
        c.line(format!("TU {} {} {}", hex(b"rows"), u64::MAX, st(&t)));
        let fps: Vec<Fp> = (0..9u64).map(|i| Fp::new(i.wrapping_mul(0x1234_5678_9abc_def1) % P)).collect();
        t.absorb_fp(b"public", &fps);
        c.line(format!("TF {} {} {}", hex(b"public"), fp_csv(&fps), st(&t)));
        t.absorb_fp(b"empty", &[]);
        c.line(format!("TF {} - {}", hex(b"empty"), st(&t)));
        for n in [1usize, 3, 4097] {
            let v = gen_fp2(n);
            t.absorb_fp2(b"pcs-vec", &v);
            c.line(format!("TF2 {} fgen:{n} {}", hex(b"pcs-vec"), st(&t)));
        }
        let v = vec![Fp2::new(Fp::new(5), Fp::new(P - 1)), Fp2::ZERO, Fp2::ONE];
        t.absorb_fp2(b"sc-round", &v);
        c.line(format!("TF2 {} v:{} {}", hex(b"sc-round"), fp2_csv(&v), st(&t)));
        if mode == 1 {
            // an opening's clear vector at W16R2 8B: 16,664 Fp2 = 266,624 bytes
            let v = gen_fp2(16_664);
            t.absorb_fp2(b"pcs-vec", &v);
            c.line(format!("TF2 {} fgen:16664 {}", hex(b"pcs-vec"), st(&t)));
        }
        // challenges of every kind, interleaved with absorbs
        for round in 0..6u64 {
            let x = t.challenge_fp();
            c.line(format!("TCF {} {}", x.0, st(&t)));
            let y = t.challenge_fp2();
            c.line(format!("TCF2 {} {} {}", y.c0.0, y.c1.0, st(&t)));
            let n = [1usize, 2, 5][round as usize % 3];
            let v = t.challenge_fp2_vec(n);
            c.line(format!("TCV {n} {} {}", fp2_csv(&v), st(&t)));
            for (n, bound) in [(1usize, 2usize), (4, 16), (5, 1 << 10), (12, 64), (37, 1 << 16), (0, 8)] {
                let idx = t.challenge_indices(n, bound);
                let s = if idx.is_empty() { "-".to_string() } else { idx.iter().map(|i| i.to_string()).collect::<Vec<_>>().join(",") };
                c.line(format!("TCI {n} {bound} {s} {}", st(&t)));
            }
            t.absorb(b"sc-round", &gen_bytes(500 + round, 48));
            c.line(format!("TA {} gen:{}:48 {}", hex(b"sc-round"), 500 + round, st(&t)));
        }
    }
}

fn tag_line(c: &mut Corpus, name: &str, t: &HashTag) {
    c.line(format!("MTAG {name} {} {} {} {}", key_or_dash(t.transcript_key()), key_or_dash(t.column_key()), key_or_dash(t.leaf_key()), key_or_dash(t.node_key())));
}

/// Merkle trees over 2^k leaves (k = 0..8): roots and every path, honest and tampered.
fn merkle_records(c: &mut Corpus) {
    let tags = [("legacy", HashTag::legacy()), ("rungg", HashTag::for_profile(RUNG_G)), ("m125", HashTag::for_profile(M125))];
    for (name, t) in &tags {
        tag_line(c, name, t);
    }
    for (name, t) in &tags {
        for k in 0..=8u32 {
            let n = 1usize << k;
            let leaves: Vec<[u8; 32]> = (0..n as u64).map(|i| *blake3::hash(&i.to_le_bytes()).as_bytes()).collect();
            let tree = MerkleTree::build_keyed(leaves.clone(), t.node_key());
            let root = tree.root();
            // the root of the tree over blake3(le64 i), i < n
            c.line(format!("MB {name} {n} {}", hex(&root)));
            let positions: Vec<usize> = if k <= 3 { (0..n).collect() } else { vec![0, n / 3, n - 1] };
            for j in positions {
                let p = tree.path(j);
                let ok = MerkleTree::verify_path_keyed(&root, j, &leaves[j], &p, t.node_key());
                assert!(ok);
                c.line(format!("MP {name} {} {j} {} {} {}", hex(&root), hex(&leaves[j]), path_csv(&p), ok as u8));
                if k >= 1 {
                    // a wrong position, a flipped leaf byte, a flipped path byte, a dropped and an extra sibling
                    let bad_j = MerkleTree::verify_path_keyed(&root, j ^ 1, &leaves[j], &p, t.node_key());
                    c.line(format!("MP {name} {} {} {} {} {}", hex(&root), j ^ 1, hex(&leaves[j]), path_csv(&p), bad_j as u8));
                    let mut bl = leaves[j];
                    bl[(j * 5) % 32] ^= 1;
                    let bad_l = MerkleTree::verify_path_keyed(&root, j, &bl, &p, t.node_key());
                    c.line(format!("MP {name} {} {j} {} {} {}", hex(&root), hex(&bl), path_csv(&p), bad_l as u8));
                    let mut bp = p.clone();
                    bp[j % p.len()][7] ^= 0x80;
                    let bad_p = MerkleTree::verify_path_keyed(&root, j, &leaves[j], &bp, t.node_key());
                    c.line(format!("MP {name} {} {j} {} {} {}", hex(&root), hex(&leaves[j]), path_csv(&bp), bad_p as u8));
                    let short = &p[..p.len() - 1];
                    let bad_s = MerkleTree::verify_path_keyed(&root, j, &leaves[j], short, t.node_key());
                    c.line(format!("MP {name} {} {j} {} {} {}", hex(&root), hex(&leaves[j]), path_csv(short), bad_s as u8));
                }
                let mut long = p.clone();
                long.push(leaves[0]);
                let bad_x = MerkleTree::verify_path_keyed(&root, j, &leaves[j], &long, t.node_key());
                c.line(format!("MP {name} {} {j} {} {} {}", hex(&root), hex(&leaves[j]), path_csv(&long), bad_x as u8));
            }
        }
        // the salted-leaf and node calls on their own
        let (a, b) = (gen_bytes(77, 32), gen_bytes(78, 32));
        let (a, b): ([u8; 32], [u8; 32]) = (a.try_into().unwrap(), b.try_into().unwrap());
        c.line(format!("MLEAF {name} {} {} {}", hex(&a), hex(&b), hex(&pcs::salt_leaf_keyed(&a, &b, t.leaf_key()))));
        c.line(format!("MNODE {name} {} {} {}", hex(&a), hex(&b), hex(&hash_pair_keyed(&a, &b, t.node_key()))));
        for (rows, seed) in [(1usize, 1u64), (3, 2), (9, 3), (40, 4)] {
            let col: Vec<Fp> = (0..rows as u64).map(|i| Fp::new((seed * 1_000_003 + i).wrapping_mul(0x9E37_79B9_7F4A_7C15) % P)).collect();
            c.line(format!("MCOL {name} {} {}", fp_csv(&col), hex(&column_digest(&col, t.column_key()))));
        }
    }
}

/// A whole tagged PCS opening, made and accepted by the crate (`commit_zk_owned_with_tag`, `open_zk`,
/// `verify_zk_tagged`): the verifier's transcript replayed and every opened column, plus tampered columns.
fn pcs_records(c: &mut Corpus) {
    for (name, profile, log_cols, inv_rate, q, seed) in [("rungg", Some(RUNG_G), 4u32, 4usize, 12usize, 31u64), ("m125", Some(M125), 5, 2, 20, 32), ("legacy", None, 4, 4, 12, 33)] {
        let tag = profile.map(HashTag::for_profile).unwrap_or_else(HashTag::legacy);
        let p = PcsParams { log_cols, inv_rate, num_col_checks: q };
        let n = p.cols();
        let nn = p.enc_cols();
        let ntt = NttTables::new(log_cols + 4);
        let mut rng = ZkRng::new(seed, b"lean-l5 pcs corpus");
        let rows = 3usize;
        let mut d: Vec<Fp> = (0..rows * n).map(|i| Fp::from_i64(((i as i64 * 37) % 256) - 128)).collect();
        for r in [1usize, 2] {
            for j in 0..n {
                d[r * n + j] = rng.fp();
            }
        }
        let zk = ZkOpts::standard(&p);
        let mut cmz = pcs::commit_zk_owned_with_tag(&Cpu, &p, d.clone(), &ntt, &zk, &mut rng, &tag);
        cmz.mask_rows = vec![1];
        cmz.prox_mask_row = Some(2);
        let pt: Vec<Fp2> = (0..log_cols as u64).map(|i| Fp2::new(Fp::new(3000 + i * 7 + 3), Fp::new(3 + i * 11 + 5))).collect();
        let e = Fp2::new(Fp::new(99991), Fp::new(7));
        let vp = eval_mle_base(&d[0..n], &pt);
        let vr = eval_mle_base(&d[n..2 * n], &pt);
        let claims = vec![ZClaim {
            parts: vec![
                ZPart { slice: Slice { offset: 0, log_size: log_cols }, coef: Fp2::ONE.sub(e), point: pt.clone() },
                ZPart { slice: Slice { offset: n, log_size: log_cols }, coef: e, point: pt.clone() },
            ],
            value: Fp2::ONE.sub(e).mul(vp).add(e.mul(vr)),
        }];
        let root = cmz.commitment().root;
        let domain = b"lean-l5/pcs-opening";
        let mk = || {
            let mut t = match tag.transcript_key() {
                Some(k) => Transcript::new_tagged(domain, *k),
                None => Transcript::new(domain),
            };
            t.absorb(b"root", &root);
            t
        };
        let mut tp = mk();
        let op = pcs::open_zk(&cmz, &claims, &mut tp);
        let mut tv = mk();
        pcs::verify_zk_tagged(&p, &zk, &cmz.commitment(), &claims, &op, &ntt, &mut tv, &tag).expect("the opening verifies");
        assert_eq!(tv.state(), tp.state());
        assert_eq!(pcs::zk_groups_for_record(&cmz, &claims), 1);
        c.line(format!("PCS {name} {} {} {rows} {nn} {q} {}", hex(domain), hex(&root), op.group_vecs.len()));
        for g in &op.group_vecs {
            c.line(format!("PCSG {}", fp2_csv(g)));
        }
        c.line(format!("PCSP {}", fp2_csv(&op.prox_vec)));
        let depth = nn.trailing_zeros() as usize;
        for (j, col, salt, path) in &op.columns {
            c.line(format!("PCSC {j} {} {} {}", fp_csv(col), hex(salt), path_csv(path)));
        }
        c.line(format!("PCSEND {}", hex(&tv.state())));
        // per-column checks, honest and tampered, with the crate's verdict on the same column
        let verdict = |j: usize, col: &[Fp], salt: &[u8; 32], path: &[[u8; 32]]| -> bool {
            path.len() == depth && col.len() == rows && MerkleTree::verify_path_keyed(&root, j, &pcs::salt_leaf_keyed(&column_digest(col, tag.column_key()), salt, tag.leaf_key()), path, tag.node_key())
        };
        for (k, (j, col, salt, path)) in op.columns.iter().enumerate().take(4) {
            let mut emit = |j: usize, col: &[Fp], salt: &[u8; 32], path: &[[u8; 32]]| {
                let v = verdict(j, col, salt, path);
                c.line(format!("MK {name} {depth} {rows} {} {j} {} {} {} {}", hex(&root), fp_csv(col), hex(salt), path_csv(path), v as u8));
            };
            emit(*j, col, salt, path);
            let mut c2 = col.clone();
            c2[k % rows] = c2[k % rows].add(Fp::ONE);
            emit(*j, &c2, salt, path);
            let mut s2 = *salt;
            s2[k] ^= 4;
            emit(*j, col, &s2, path);
            emit(*j ^ 1, col, salt, path);
            emit(*j, &col[..rows - 1], salt, path);
            emit(*j, col, salt, &path[..depth - 1]);
            let mut p2 = path.clone();
            p2[k % depth][0] ^= 1;
            emit(*j, col, salt, &p2);
        }
        // the whole tampered opening is refused by the crate's verifier too
        let mut bad = op.clone();
        bad.columns[0].2[0] ^= 1;
        let mut tb = mk();
        assert!(pcs::verify_zk_tagged(&p, &zk, &cmz.commitment(), &claims, &bad, &ntt, &mut tb, &tag).is_err());
    }
}

#[test]
fn lean_l5_export_the_agreement_corpus() {
    let mut c = Corpus { out: String::new(), n: 0 };
    let _ = writeln!(c.out, "# D63 L5 agreement corpus (zkp-core tests/lean_l5_export.rs); one record per line");
    field_records(&mut c);
    blake3_records(&mut c);
    transcript_records(&mut c);
    merkle_records(&mut c);
    pcs_records(&mut c);
    eprintln!("LEAN-L5: {} records, {} bytes", c.n, c.out.len());
    if let Ok(path) = std::env::var("LEAN_L5_CORPUS") {
        std::fs::write(&path, &c.out).expect("write the corpus");
        eprintln!("LEAN-L5: written to {path}");
    }
}
