//! **REVIEWER SCRATCH, D24 review ROUND 4 (2026-10-17), of the native
//! Round-5 tree.** Test code only; never part of the reviewed tree.
//!
//! * `r4_1` (fast): r3_3 re-run — CS-6 at the library level on BOTH sides.
//!   A statement over blocks A; the honest prover handed B is refused by
//!   name before anything is asked or sunk; a CHEATING prover (the test-only
//!   switch) proves B under A, and every verifier entry handed B refuses by
//!   CS-6's name before the receipt or the directory is looked at.
//! * `r4_2` (fast): the parallel pre-scan of `weights_vanish_off_support`
//!   against the round-3 sequential loop, on random clean / violating
//!   matrices at every axis pair and four padded shapes.
//! * `r4_3` (fast): CS-8 field-write sweep: every `Shape` field moved by one
//!   at three shapes; which writes `check_constructed` refuses.
//! * `r4_5` (fast): `run::read_segment_bounded` while a second thread swaps
//!   the path between a regular file, a symlink to /dev/zero, a FIFO, a
//!   512 MiB sparse file, a short file and a symlink to the sparse file.

use super::layout::*;
use super::run::{self, RunShape, RunStatement, RunWitnessSource};
use super::shape::Shape;
use super::trained_calib_tests::{run_shape_for, rung_tc_calibration, synthetic_statement, trained_dense_words, TRAINED_BANDS};
use super::witness::{self, Witness};
use super::*;
use std::path::{Path, PathBuf};

fn review_tmp(tag: &str) -> PathBuf {
    let root = std::env::var_os("ZK60_REVIEW_TMP").map(PathBuf::from).unwrap_or_else(std::env::temp_dir);
    let d = root.join(format!("r4-{tag}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    d
}

fn vm_hwm_mib() -> f64 {
    std::fs::read_to_string("/proc/self/status").ok().and_then(|s| s.lines().find(|l| l.starts_with("VmHWM:")).and_then(|l| l.split_whitespace().nth(1)).and_then(|v| v.parse::<f64>().ok())).map(|k| k / 1024.0).unwrap_or(-1.0)
}

// ------------------------------------------------------------------ r4_1

fn out_plane(sh: &Shape, w: &Witness) -> Vec<i16> {
    let ids = Ids::new(sh).unwrap();
    w.planes[ids.at(A_X2)].iter().map(|v| *v as i16).collect()
}
fn in_plane(sh: &Shape, w: &Witness) -> Vec<i16> {
    let ids = Ids::new(sh).unwrap();
    w.planes[ids.at(A_X)].iter().map(|v| *v as i16).collect()
}
fn true_words(sh: &Shape, plane: &[i16]) -> Vec<i16> {
    (0..sh.tokens).flat_map(|t| plane[t * sh.d_pad..t * sh.d_pad + sh.width].to_vec()).collect()
}

/// a chained witness source that counts what it is asked
struct Chain<'a> {
    sh: &'a Shape,
    blocks: &'a [BlockPublic],
    x: Vec<i16>,
    cached: Option<(usize, Witness)>,
    next: usize,
    asked: usize,
}

impl<'a> Chain<'a> {
    fn new(sh: &'a Shape, blocks: &'a [BlockPublic], x: &[i16]) -> Chain<'a> {
        Chain { sh, blocks, x: x.to_vec(), cached: None, next: 0, asked: 0 }
    }
    fn advance(&mut self, k: usize) -> Result<(Witness, Vec<i16>), String> {
        assert_eq!(k, self.next);
        let w = witness::build_shaped(self.sh, self.blocks[k].attention(), self.blocks[k].feed_forward(), &self.x)?;
        let o = out_plane(self.sh, &w);
        self.x = true_words(self.sh, &o);
        self.next += 1;
        Ok((w, o))
    }
}

impl RunWitnessSource for Chain<'_> {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        self.asked += 1;
        match self.cached.take() {
            Some((j, w)) if j == k => Ok(w),
            _ => self.advance(k).map(|(w, _)| w),
        }
    }
    fn boundary_plane(&mut self, k: usize) -> Result<Vec<i16>, String> {
        self.asked += 1;
        let (w, o) = self.advance(k)?;
        self.cached = Some((k, w));
        Ok(o)
    }
}

fn two_blocks(sh: &Shape) -> (Vec<BlockPublic>, Vec<i16>) {
    let (w0, x) = trained_dense_words(sh, TRAINED_BANDS);
    let mut blocks = Vec::new();
    for k in 0..2usize {
        let mut w = w0.clone();
        for (i, m) in w.iter_mut().enumerate() {
            let len = m.len();
            m.rotate_left((k * (7 + i)) % len);
        }
        let (public, ff) = super::dense_tests::statement_of_words(sh, &w);
        blocks.push(BlockPublic::new(public, ff));
    }
    (blocks, x)
}

fn honest_chain(sh: &Shape, blocks: &[BlockPublic], x: &[i16]) -> (Vec<i16>, Vec<i16>) {
    let w0 = witness::build_shaped(sh, blocks[0].attention(), blocks[0].feed_forward(), x).unwrap();
    let (i0, o0) = (in_plane(sh, &w0), out_plane(sh, &w0));
    let w1 = witness::build_shaped(sh, blocks[1].attention(), blocks[1].feed_forward(), &true_words(sh, &o0)).unwrap();
    (i0, out_plane(sh, &w1))
}

#[test]
fn r4_1_r3_3_cs6_refuses_blocks_b_under_a_statement_over_a_on_both_sides() {
    let sh = Shape::rung_tc(&rung_tc_calibration()).unwrap();
    let (a, x) = two_blocks(&sh);
    // B: block 1's gamma_a word 0 moved (as in r3_3)
    let mut b = a.clone();
    {
        let at = b[1].attention().clone();
        let mut gamma = at.gamma_a.clone();
        gamma[0] = if gamma[0] == 127 { 126 } else { gamma[0] + 1 };
        let pubb = AttentionPublic::new_shaped(&sh, &at.wq, &at.wk, &at.wv, &at.wo, &gamma, &at.rope_cos, &at.rope_sin, &at.exp).unwrap();
        b[1] = BlockPublic::new(pubb, b[1].feed_forward().clone());
    }
    assert_ne!(a[1].digest(), b[1].digest());
    assert_eq!(a[0].digest(), b[0].digest());
    let ctx = *blake3::hash(b"review r4-1").as_bytes();
    let (pin_b, pout_b) = honest_chain(&sh, &b, &x);
    let stmt = |expected: ExpectedIo| RunStatement::new_bound(run_shape_for(&sh, 2), ctx, expected, &a, &[(0, 0), (0, 0)], &synthetic_statement(&sh, &a)).expect("the statement over blocks A");

    // (1) the HONEST prover handed B under the statement over A
    let (e1, owners) = prepare_endpoints(IoSpec::new_shaped(&sh, ctx, 0, 0).unwrap(), &pin_b, &pout_b).unwrap();
    let st = stmt(e1);
    let mut src = Chain::new(&sh, &b, &x);
    let mut sunk = 0usize;
    let r = run::prove_run(&st, &b, &mut src, owners, &mut |_, _| {
        sunk += 1;
        Ok(())
    });
    let e = r.err().expect("the honest run prover PROVED blocks B under a statement over A");
    eprintln!("REVIEW-R4-1 (1) honest prover, blocks B under A: refused: {e}");
    assert!(e.contains("ruling CS-6") && e.contains("block 1"), "{e}");
    assert_eq!((src.asked, sunk), (0, 0), "something was asked or sunk before the CS-6 refusal");

    // (2) a CHEATING prover (the test-only switch) proves B under A
    let (e2, owners) = prepare_endpoints(IoSpec::new_shaped(&sh, ctx, 0, 0).unwrap(), &pin_b, &pout_b).unwrap();
    let st2 = stmt(e2);
    let mut segs: Vec<Vec<u8>> = Vec::new();
    {
        let _cheat = super::protocol::CheatingProver::on();
        run::prove_run(&st2, &b, &mut Chain::new(&sh, &b, &x), owners, &mut |_, s| {
            segs.push(s);
            Ok(())
        })
        .expect("the cheating prover proves blocks B under the statement over A");
    }
    assert!(!super::protocol::cheating_prover_is_on(), "the switch outlived its guard");
    eprintln!("REVIEW-R4-1 (2) cheating prover: B under A proved, {} segments, {} B", segs.len(), segs.iter().map(|s| s.len()).sum::<usize>());
    // r3_3 exactly: the verifier handed B (r3: ACCEPTED)
    let e = run::verify_run(&st2, &b, &segs).err().expect("r3_3 STILL OPEN: verify_run ACCEPTED blocks B under a statement over A");
    eprintln!("REVIEW-R4-1 (2a) verify_run, verifier handed B: refused: {e}");
    assert!(e.contains("ruling CS-6") && e.contains("block 1") && e.contains("before anything is absorbed"), "{e}");
    // the same with the cheating switch ON in the verifier's thread: the
    // verifier never consults it
    {
        let _cheat = super::protocol::CheatingProver::on();
        let e = run::verify_run(&st2, &b, &segs).err().expect("verify_run with the cheating switch on ACCEPTED B under A");
        assert!(e.contains("ruling CS-6"), "{e}");
    }
    // the statement's blocks A: rejected by the transcript (not CS-6)
    let e = run::verify_run(&st2, &a, &segs).err().expect("the B proof VERIFIED against blocks A");
    eprintln!("REVIEW-R4-1 (2b) verify_run, verifier handed A: rejected: {}", e.chars().take(160).collect::<String>());
    assert!(!e.contains("ruling CS-6"), "{e}");
    // the streaming verifier, from a real directory and from no directory
    let dir = review_tmp("cs6");
    for (k, s) in segs.iter().enumerate() {
        std::fs::write(dir.join(super::run_sink::segment_file_name(k)), s).unwrap();
    }
    let e = run::verify_run_from_dir(&st2, &b, &dir).err().expect("verify_run_from_dir ACCEPTED B under A");
    assert!(e.contains("ruling CS-6"), "{e}");
    let nowhere = dir.join("no-such-dir");
    let e = run::verify_run_from_dir(&st2, &b, &nowhere).err().unwrap();
    assert!(e.contains("ruling CS-6"), "{e}: the directory was read before CS-6");
    let e = run::verify_run_from_dir(&st2, &a, &dir).err().expect("the B proof VERIFIED from the directory against A");
    assert!(!e.contains("ruling CS-6"), "{e}");
    // the count, by name, both ways
    let e = run::verify_run(&st2, &a[..1], &segs).err().unwrap();
    assert!(e.contains("ruling CS-6") && e.contains("1 public statements"), "{e}");
    let three = [a[0].clone(), a[1].clone(), a[1].clone()];
    let e = run::verify_run(&st2, &three, &segs).err().unwrap();
    assert!(e.contains("ruling CS-6") && e.contains("3 public statements"), "{e}");
    let _ = std::fs::remove_dir_all(&dir);

    // (3) control: the honest A chain under the statement over A verifies
    let (pin_a, pout_a) = honest_chain(&sh, &a, &x);
    let (e3, owners) = prepare_endpoints(IoSpec::new_shaped(&sh, ctx, 0, 0).unwrap(), &pin_a, &pout_a).unwrap();
    let st3 = stmt(e3);
    let mut segs3 = Vec::new();
    run::prove_run(&st3, &a, &mut Chain::new(&sh, &a, &x), owners, &mut |_, s| {
        segs3.push(s);
        Ok(())
    })
    .expect("the honest A run proves");
    run::verify_run(&st3, &a, &segs3).expect("the honest A run verifies");
    eprintln!("REVIEW-R4-1 (3) honest A chain under the statement over A: verifies");
}

// ------------------------------------------------------------------ r4_2

/// the ROUND-3 sequential loop of `weights_vanish_off_support`, verbatim
fn off_support_reference(sh: &Shape, w: &[i8], outer: Axis, inner: Axis) -> Result<(), String> {
    let (no, ni) = (outer.len(sh), inner.len(sh));
    for o in 0..no {
        let o_ok = outer.supported(sh, o).is_ok();
        for i in 0..ni {
            if w[o * ni + i] == 0 {
                continue;
            }
            if !o_ok {
                outer.supported(sh, o)?;
            }
            inner.supported(sh, i)?;
        }
    }
    Ok(())
}

struct XorShift(u64);
impl XorShift {
    fn next(&mut self) -> u64 {
        let mut x = self.0;
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        self.0 = x;
        x
    }
    fn below(&mut self, n: usize) -> usize {
        (self.next() % n as u64) as usize
    }
    fn nonzero_i8(&mut self) -> i8 {
        let v = (self.next() % 255) as i16 - 127;
        if v == 0 {
            1
        } else {
            v as i8
        }
    }
}

#[test]
fn r4_2_the_parallel_off_support_prescan_equals_the_sequential_loop() {
    let mut rng = XorShift(0x9e37_79b9_7f4a_7c15);
    let shapes = [Shape::rung_g(), Shape::rung_p2(), Shape::rung_k4(), Shape::rung_tc(&rung_tc_calibration()).unwrap()];
    let (mut cases, mut violating) = (0usize, 0usize);
    for sh in &shapes {
        let kv = sh.kv_heads * sh.head_dim;
        let pairs = [("Q,D", Axis::Q, Axis::D), ("Kv,D", Axis::Full(kv), Axis::D), ("D,Q", Axis::D, Axis::Q), ("1,D", Axis::Full(1), Axis::D), ("D,F", Axis::D, Axis::F), ("F,D", Axis::F, Axis::D)];
        for (pname, outer, inner) in pairs {
            let (no, ni) = (outer.len(sh), inner.len(sh));
            let mut clean = vec![0i8; no * ni];
            let mut off: Vec<usize> = Vec::new();
            for o in 0..no {
                for i in 0..ni {
                    if outer.supported(sh, o).is_ok() && inner.supported(sh, i).is_ok() {
                        clean[o * ni + i] = rng.nonzero_i8();
                    } else {
                        off.push(o * ni + i);
                    }
                }
            }
            assert_eq!(super::weights_vanish_off_support(sh, &clean, outer, inner), Ok(()), "{} {pname}: a clean matrix was refused", sh.name);
            assert_eq!(off_support_reference(sh, &clean, outer, inner), Ok(()));
            cases += 1;
            if off.is_empty() {
                eprintln!("REVIEW-R4-2 {} [{pname}] {no} x {ni}: no off-support entry", sh.name);
                continue;
            }
            // first, last and random single violations; then 2..6 at once
            let mut singles: Vec<usize> = vec![off[0], off[off.len() - 1]];
            for _ in 0..300 {
                singles.push(off[rng.below(off.len())]);
            }
            for p in singles {
                let mut w = clean.clone();
                w[p] = rng.nonzero_i8();
                let (got, want) = (super::weights_vanish_off_support(sh, &w, outer, inner), off_support_reference(sh, &w, outer, inner));
                assert!(want.is_err());
                assert_eq!(got, want, "{} [{pname}] single violation at {p}", sh.name);
                cases += 1;
                violating += 1;
            }
            for _ in 0..100 {
                let mut w = clean.clone();
                let m = 2 + rng.below(5);
                for _ in 0..m {
                    let p = off[rng.below(off.len())];
                    w[p] = rng.nonzero_i8();
                }
                let (got, want) = (super::weights_vanish_off_support(sh, &w, outer, inner), off_support_reference(sh, &w, outer, inner));
                assert_eq!(got, want, "{} [{pname}] multiple violations", sh.name);
                cases += 1;
                violating += 1;
            }
            eprintln!("REVIEW-R4-2 {} [{pname}] {no} x {ni}: {} off-support entries; pre-scan == sequential on every case", sh.name, off.len());
        }
    }
    eprintln!("REVIEW-R4-2 total: {cases} cases ({violating} violating), every verdict and first error equal");
}

// ------------------------------------------------------------------ r4_3

#[test]
fn r4_3_cs8_every_shape_field_write_and_check_constructed() {
    let cal = rung_tc_calibration();
    let shapes = [Shape::rung_g(), Shape::rung_tc(&cal).unwrap(), Shape::m125()];
    type Mut = (&'static str, fn(&mut Shape));
    let muts: [Mut; 35] = [
        ("name", |s| s.name = "another name"),
        ("profile", |s| s.profile = "hashline-zk-mr1/private-block-rung-c6-t32-dev/1"),
        ("tokens", |s| s.tokens += 1),
        ("width", |s| s.width += 1),
        ("hidden", |s| s.hidden += 1),
        ("q_heads", |s| s.q_heads += 1),
        ("head_dim", |s| s.head_dim += 1),
        ("kv_heads", |s| s.kv_heads += 1),
        ("log_cols", |s| s.log_cols += 1),
        ("inv_rate", |s| s.inv_rate += 1),
        ("opened_cols", |s| s.opened_cols += 1),
        ("f_e", |s| s.f_e += 1),
        ("endpoint_rows", |s| s.endpoint_rows += 1),
        ("endpoint_log_n", |s| s.endpoint_log_n += 1),
        ("endpoint_inv_rate", |s| s.endpoint_inv_rate += 1),
        ("endpoint_general", |s| s.endpoint_general = !s.endpoint_general),
        ("norm_wrho", |s| s.norm_wrho += 1),
        ("wrho_s", |s| s.wrho_s += 1),
        ("norm_tn", |s| s.norm_tn ^= 1),
        ("norm_cn_a", |s| s.norm_cn_a += 1),
        ("norm_cn_m", |s| s.norm_cn_m += 1),
        ("norm_ceps", |s| s.norm_ceps += 1),
        ("sh_ao", |s| s.sh_ao ^= 1),
        ("sh_qkv", |s| s.sh_qkv ^= 1),
        ("sh_s", |s| s.sh_s ^= 1),
        ("sh_o", |s| s.sh_o ^= 1),
        ("sh_g", |s| s.sh_g ^= 1),
        ("sh_h", |s| s.sh_h ^= 1),
        ("sh_z", |s| s.sh_z ^= 1),
        ("trained_calibration", |s| s.trained_calibration = !s.trained_calibration),
        ("t_pad", |s| s.t_pad *= 2),
        ("d_pad", |s| s.d_pad *= 2),
        ("h_pad", |s| s.h_pad *= 2),
        ("f_pad", |s| s.f_pad *= 2),
        ("d_max", |s| s.d_max += 1),
    ];
    for sh in &shapes {
        sh.check_constructed().unwrap_or_else(|e| panic!("{}: the honest shape is refused: {e}", sh.name));
        let mut accepted = Vec::new();
        for (name, m) in muts.iter() {
            let mut s = sh.clone();
            m(&mut s);
            if s == *sh {
                continue;
            }
            match s.check_constructed() {
                Ok(()) => {
                    // a write CS-8 admits must still be refused by the layout
                    // or be a trained calibration input the statement binds
                    let lay = Layout::for_shape(&s).map(|_| "layout builds").unwrap_or("layout refused");
                    accepted.push(format!("{name} ({lay})"));
                }
                Err(e) => assert!(e.contains("ruling CS-8") || e.contains("ruling CS-9"), "{} {name}: refused, but not by CS-8's name: {e}", sh.name),
            }
        }
        eprintln!("REVIEW-R4-3 {} (trained {}): field writes check_constructed ADMITS: {:?}", sh.name, sh.trained_calibration, accepted);
        if !sh.trained_calibration {
            assert!(accepted.is_empty(), "{}: a frozen shape admitted the writes {accepted:?}", sh.name);
        }
    }
}

// ------------------------------------------------------------------ r4_5

#[test]
fn r4_5_read_segment_bounded_under_a_concurrent_swap() {
    use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
    use std::sync::Arc;
    let g = Shape::rung_g();
    let (pd, fd, _) = super::dense_tests::dense_case(&g);
    let x = BlockPublic::new(pd, fd);
    let ctx = *blake3::hash(b"review r4-5").as_bytes();
    let expected = ExpectedIo::from_roots(IoSpec::new_shaped(&g, ctx, 0, 0).unwrap(), [1; 32], [2; 32]);
    let st = RunStatement::new(RunShape::rung_g(1).unwrap(), ctx, expected, &[x], &[(0, 0)]).expect("a one-block rung-G statement");
    let dir = review_tmp("race");
    let target = dir.join("segment-000.bin");
    std::fs::write(&target, b"x").unwrap();
    let probe = run::read_segment_bounded(&st, 0, &target).unwrap_err();
    let want: usize = probe.split("the counted length is ").nth(1).and_then(|s| s.split(|c: char| !c.is_ascii_digit()).next()).and_then(|s| s.parse().ok()).unwrap_or_else(|| panic!("no counted length in {probe}"));
    eprintln!("REVIEW-R4-5 counted length of segment 0 at rung-G: {want} B");
    let good: Vec<u8> = (0..want).map(|i| (i * 31 + 7) as u8).collect();
    let other: Vec<u8> = vec![0x5a; want];
    let c = |n: &str| dir.join(n);
    std::fs::write(c("c-good"), &good).unwrap();
    std::fs::write(c("c-other"), &other).unwrap();
    std::fs::write(c("c-short"), &good[..want - 1]).unwrap();
    std::fs::OpenOptions::new().create(true).write(true).truncate(true).open(c("c-big")).and_then(|f| f.set_len(512 << 20)).unwrap();
    std::os::unix::fs::symlink("/dev/zero", c("c-zero-link")).unwrap();
    std::os::unix::fs::symlink(c("c-big"), c("c-big-link")).unwrap();
    assert!(std::process::Command::new("mkfifo").arg(c("c-fifo")).status().map(|s| s.success()).unwrap_or(false), "mkfifo");
    std::fs::copy(c("c-good"), &target).unwrap();
    let stop = Arc::new(AtomicBool::new(false));
    let swaps = Arc::new(AtomicUsize::new(0));
    let swapper = {
        let (stop, swaps, dir, target) = (stop.clone(), swaps.clone(), dir.clone(), target.clone());
        std::thread::spawn(move || {
            let cands = ["c-good", "c-zero-link", "c-fifo", "c-big", "c-short", "c-other", "c-big-link"];
            let tmp = dir.join("swap.tmp");
            while !stop.load(Ordering::Relaxed) {
                for n in cands {
                    let _ = std::fs::remove_file(&tmp);
                    std::fs::hard_link(dir.join(n), &tmp).unwrap();
                    std::fs::rename(&tmp, &target).unwrap();
                    swaps.fetch_add(1, Ordering::Relaxed);
                }
            }
        })
    };
    let classes = ["not a regular file", "before it is read", "cannot be opened as a regular file", "changed after its check", "read "];
    let mut counts = [0usize; 5];
    let (mut ok_good, mut ok_other, mut calls) = (0usize, 0usize, 0usize);
    let mut unknown: Vec<String> = Vec::new();
    let mut worst = 0f64;
    let t0 = std::time::Instant::now();
    while t0.elapsed().as_secs_f64() < 12.0 {
        let t = std::time::Instant::now();
        let r = run::read_segment_bounded(&st, 0, &target);
        worst = worst.max(t.elapsed().as_secs_f64());
        calls += 1;
        match r {
            Ok(b) => {
                assert_eq!(b.len(), want, "the bounded reader returned {} B, not the counted {want}", b.len());
                if b == good {
                    ok_good += 1;
                } else if b == other {
                    ok_other += 1;
                } else {
                    panic!("the bounded reader returned {} B that are neither regular candidate", b.len());
                }
            }
            Err(e) => match classes.iter().position(|k| e.contains(k)) {
                Some(i) => counts[i] += 1,
                None => {
                    if unknown.len() < 5 {
                        unknown.push(e);
                    }
                }
            },
        }
    }
    stop.store(true, Ordering::Relaxed);
    swapper.join().unwrap();
    eprintln!(
        "REVIEW-R4-5 {calls} reads during {} swaps in {:.1} s: Ok(good) {ok_good}, Ok(other, same length) {ok_other}; refused by lstat type {}, by lstat length {}, by O_NOFOLLOW open {}, by fstat after open {}, by read length {}; unknown {:?}; slowest call {:.4} s; VmHWM {:.0} MiB",
        swaps.load(Ordering::Relaxed),
        t0.elapsed().as_secs_f64(),
        counts[0],
        counts[1],
        counts[2],
        counts[3],
        counts[4],
        unknown,
        worst,
        vm_hwm_mib()
    );
    assert!(unknown.is_empty(), "refusals of an unknown kind: {unknown:?}");
    assert!(worst < 2.0, "a bounded read took {worst} s");
    let _ = std::fs::remove_dir_all(&dir);
}

#[allow(dead_code)]
fn _unused(_: &Path) {}
