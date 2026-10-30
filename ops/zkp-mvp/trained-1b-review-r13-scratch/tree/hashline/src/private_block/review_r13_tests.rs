//! D24 review R13 (reviewer's scratch copy ONLY; never part of Sol's tree).
//!
//! * generic honest witnesses (the reviewer's own fixtures: random int8 weights
//!   over the whole symmetric class, signed gains, scores over [-49, 44], an
//!   input row whose attention-norm output is exactly -32768) prove, verify and
//!   equal the reviewer's independent integer reference;
//! * self-consistent alternative-remainder witnesses at four R13 windows
//!   (gate, up, down, masked score) and an ACT3 pad-position witness are
//!   rejected by a fresh verifier;
//! * a two-channel group-id swap (witness side and statement side);
//! * trained-door refusals of doctored exports (prover-supplied derived table,
//!   doctored raw table, five groups, the (0,-8) member at a Standard profile,
//!   -128 weight / gain, out-of-class multipliers, legacy schema naming R13);
//! * the native lookup windows of every widened word, the score and the gate;
//! * the actual Shieldstral layers 0 and 25 (the (0,-8) member) as native
//!   witnesses for the reviewer's reference (one checkpoint stream).
use super::*;
use super::accuracy_layout::Limbs as L;
use super::layout::*;
use super::shape::Shape;
use super::run::{self, RunShape, RunStatement, RunWitnessSource};
use super::trained_block::TrainedExport;
use super::witness::{self, Witness};
use std::io::Write as _;
use std::path::{Path, PathBuf};

fn scratch() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../..")
}
fn rv(name: &str) -> PathBuf {
    scratch().join("loader-fixtures-rv").join(name)
}
fn evidence() -> PathBuf {
    PathBuf::from(std::env::var("RV13_EVIDENCE").expect("RV13_EVIDENCE names the reviewer's evidence directory"))
}

struct One(Option<Witness>);
impl RunWitnessSource for One {
    fn witness(&mut self, k: usize) -> Result<Witness, String> {
        if k != 0 {
            return Err("one stage".into());
        }
        self.0.take().ok_or("witness consumed".into())
    }
    fn boundary_plane(&mut self, _k: usize) -> Result<Vec<i16>, String> {
        Err("no internal boundary".into())
    }
}

struct Case {
    ex: TrainedExport,
    c: super::trained_block::Constants,
    seed: Shape,
    layer: super::trained_block::TrainedLayer,
    sh: Shape,
    x: Vec<i16>,
    expected: Vec<i16>,
}

fn load(name: &str, dd: bool) -> Case {
    let mut ex = TrainedExport::load(&rv(name)).unwrap_or_else(|e| panic!("{name}: {e}"));
    ex.accuracy_dd = dd;
    let c = ex.run_constants(&[0]).unwrap();
    let seed = ex.shape_for(&c).unwrap();
    let layer = ex.load_layer(&seed, &c, 0, false).unwrap_or_else(|e| panic!("{name}: {e}"));
    let sh = layer.record.shape_at(&seed).unwrap();
    let (x, expected) = ex.load_seq(&sh, "public", 0).unwrap();
    Case { ex, c, seed, layer, sh, x, expected }
}

/// Prove one stage at `prove_blk` with `wit`, verify in a fresh verifier at
/// `verify_blk` (the statement is built from the verifier's block). Returns
/// the verifier's result and the receipt size. `tamper`: an honest receipt
/// with one flipped byte must be refused.
fn run_case(cs: &Case, prove_blk: &BlockPublic, verify_blk: &BlockPublic, wit: Witness, cheat: bool, tamper: bool) -> (Result<(), String>, usize) {
    let ids = Ids::new(&cs.sh).unwrap();
    let input: Vec<i16> = wit.planes[ids.at(A_X)].iter().map(|&v| v as i16).collect();
    let output: Vec<i16> = wit.planes[ids.at(A_X2)].iter().map(|&v| v as i16).collect();
    let statement_of = |blk: &BlockPublic| {
        if blk.digest() == cs.layer.blk.digest() {
            cs.ex.statement(&cs.seed, &cs.c, &[&cs.layer]).unwrap()
        } else {
            let mut rec = super::trained_statement::LayerRecord::of_block(0, blk, vec![]);
            rec.manifest_sha256 = [77; 32];
            cs.ex.statement_of_records(&cs.seed, &cs.c, vec![rec]).unwrap()
        }
    };
    let context = [73u8; 32];
    let spec = IoSpec::new_shaped(&cs.seed, context, 0, 0).unwrap();
    let (expected, owners) = prepare_endpoints(spec, &input, &output).unwrap();
    let pblocks = vec![prove_blk.clone()];
    let st = RunStatement::new_bound(RunShape::accuracy(cs.seed.clone(), 1).unwrap(), context, expected.clone(), &pblocks, &[(0, 0)], &statement_of(prove_blk)).unwrap();
    let guard = if cheat { Some(super::protocol::CheatingProver::on()) } else { None };
    let mut segs = Vec::new();
    let mut src = One(Some(wit));
    let proved = run::prove_run(&st, &pblocks, &mut src, owners, &mut |_, b| {
        segs.push(b);
        Ok(())
    });
    drop(guard);
    if let Err(e) = proved {
        return (Err(format!("PROVER REFUSED (no receipt): {e}")), 0);
    }
    let n = segs.iter().map(|s| s.len()).sum();
    let vblocks = vec![verify_blk.clone()];
    let vst = RunStatement::new_bound(RunShape::accuracy(cs.seed.clone(), 1).unwrap(), context, expected, &vblocks, &[(0, 0)], &statement_of(verify_blk)).unwrap();
    let verified = run::verify_run(&vst, &vblocks, &segs).map(|_| ());
    if tamper && verified.is_ok() {
        let mut bad = segs.clone();
        let mid = bad[0].len() / 2;
        bad[0][mid] ^= 1;
        assert!(run::verify_run(&vst, &vblocks, &bad).is_err(), "a tampered honest receipt was accepted");
    }
    (verified, n)
}

fn dense(sh: &Shape, plane: &[i64], dom: Dom) -> Vec<i64> {
    let (t, dh, tp) = (sh.tokens, sh.head_dim, sh.t_pad);
    let mut v = Vec::new();
    match dom {
        Dom::D => {
            for a in 0..t {
                for i in 0..sh.width {
                    v.push(plane[a * sh.d_pad + i]);
                }
            }
        }
        Dom::Q => {
            for a in 0..t {
                for h in 0..sh.q_heads {
                    for i in 0..dh {
                        v.push(plane[a * sh.q_pad() + sh.head_slot(h) * dh + i]);
                    }
                }
            }
        }
        Dom::Kv => {
            for a in 0..t {
                for k in 0..sh.kv_heads {
                    for i in 0..dh {
                        v.push(plane[a * sh.kv_heads * dh + k * dh + i]);
                    }
                }
            }
        }
        Dom::S => {
            for h in 0..sh.q_heads {
                for a in 0..t {
                    for j in 0..t {
                        v.push(plane[(sh.head_slot(h) * tp + a) * tp + j]);
                    }
                }
            }
        }
        Dom::F => {
            for a in 0..t {
                for j in 0..sh.hidden {
                    v.push(plane[a * sh.f_pad + j]);
                }
            }
        }
        _ => panic!("no dense order for {dom:?}"),
    }
    v
}

fn dump(sh: &Shape, wit: &Witness, path: &Path) {
    let ids = Ids::new(sh).unwrap();
    let mut f = std::fs::File::create(path).unwrap();
    for (name, old, dom) in [("x", A_X, Dom::D), ("y", A_Y, Dom::D), ("q", A_Q8, Dom::Q), ("k", A_K8, Dom::Kv), ("v", A_V8, Dom::Kv),
        ("qr", A_QR8, Dom::Q), ("kr", A_KR8, Dom::Kv), ("s", A_S8, Dom::S), ("p", A_P, Dom::S), ("o", A_O8, Dom::Q),
        ("ao", A_AO, Dom::D), ("x1", A_X1, Dom::D), ("nm", A_YM, Dom::D), ("gate", A_G8, Dom::F), ("a_scaled", A_A16, Dom::F),
        ("u", A_U16, Dom::F), ("h", A_H16, Dom::F), ("z", A_Z16, Dom::D), ("x2", A_X2, Dom::D)] {
        let vals = dense(sh, &wit.planes[ids.at(old)], dom);
        let line: Vec<String> = vals.iter().map(|v| v.to_string()).collect();
        writeln!(f, "{name}\t{}", line.join("\t")).unwrap();
    }
}

fn get_limbs(wit: &Witness, low: &super::accuracy_layout::AccuracyIds, role: L, pos: usize) -> i64 {
    (0..low.count(role)).map(|k| wit.planes[low.limb(role, k)][pos] << (8 * k)).sum()
}
fn set_limbs(wit: &mut Witness, low: &super::accuracy_layout::AccuracyIds, role: L, pos: usize, value: i64) {
    let n = low.count(role);
    assert!(value >= 0 && value < 1i64 << (8 * n), "{role:?}: {value} does not fit {n} byte limbs");
    for k in 0..n {
        wit.planes[low.limb(role, k)][pos] = (value >> (8 * k)) & 255;
    }
}

#[test]
#[ignore = "reviewer R13: generic honest witnesses, independent parity, proofs"]
fn rv13_generic_witness_parity_prove_verify() {
    for name in ["rv-generic-h24", "rv-generic-low"] {
        for dd in [false, true] {
            let cs = load(name, dd);
            let wit = witness::build_for_block(&cs.sh, &cs.layer.blk, &cs.x).unwrap_or_else(|e| panic!("{name}: honest builder refused: {e}"));
            let ids = Ids::new(&cs.sh).unwrap();
            assert_eq!(dense(&cs.sh, &wit.planes[ids.at(A_X2)], Dom::D).iter().map(|&v| v as i16).collect::<Vec<_>>(), cs.expected,
                "{name} dd={dd}: native output differs from the reviewer's independent reference");
            let y = dense(&cs.sh, &wit.planes[ids.at(A_Y)], Dom::D);
            assert!(y.contains(&-32768), "{name}: the widened endpoint -32768 is not exercised");
            let s = dense(&cs.sh, &wit.planes[ids.at(A_S8)], Dom::S);
            if !dd {
                dump(&cs.sh, &wit, &evidence().join(format!("{name}.native.tsv")));
            }
            let t0 = std::time::Instant::now();
            let (r, n) = run_case(&cs, &cs.layer.blk, &cs.layer.blk, wit, false, true);
            r.unwrap_or_else(|e| panic!("{name} dd={dd}: honest generic receipt refused: {e}"));
            eprintln!("RV13-GENERIC {name} dd={dd}: native x2 = reviewer reference ({} words), y min {} (endpoint -32768 present), score range [{}, {}], receipt {n} B verified, tampered refused, {:.1} s",
                cs.expected.len(), y.iter().min().unwrap(), s.iter().min().unwrap(), s.iter().max().unwrap(), t0.elapsed().as_secs_f64());
        }
    }
}

#[derive(Clone, Copy, Debug)]
enum Alt {
    Gate,
    Up,
    Down,
    MaskedScore,
    PadAct,
    GroupSwap,
}

fn mutate(cs: &Case, wit: &mut Witness, alt: Alt) -> String {
    let sh = &cs.sh;
    let ids = Ids::new(sh).unwrap();
    let low = ids.accuracy().unwrap();
    let data = cs.layer.blk.accuracy().unwrap();
    let p = sh.accuracy_precision().unwrap();
    let (gshift, r) = (data.folds().gate.shift, data.folds().product.shift);
    match alt {
        Alt::Gate => {
            for t in 0..sh.tokens {
                for j in 0..sh.hidden {
                    let pos = t * sh.f_pad + j;
                    let (g, u, h) = (wit.planes[ids.at(A_G8)][pos], wit.planes[ids.at(A_U16)][pos], wit.planes[ids.at(A_H16)][pos]);
                    let rg = get_limbs(wit, low, L::Rg, pos);
                    if g <= -2048 || rg + (1i64 << gshift) >= 1i64 << 24 {
                        continue;
                    }
                    let a2 = data.scaled_tables()[data.group_ids()[j]][(g - 1 + 2048) as usize];
                    let num = a2 * u + (1i64 << (r - 1));
                    if num.div_euclid(1i64 << r) != h || a2 == wit.planes[ids.at(A_A16)][pos] {
                        continue;
                    }
                    wit.planes[ids.at(A_G8)][pos] = g - 1;
                    set_limbs(wit, low, L::Rg, pos, rg + (1i64 << gshift));
                    wit.planes[ids.at(A_A16)][pos] = a2;
                    set_limbs(wit, low, L::Rh, pos, num.rem_euclid(1i64 << r));
                    return format!("gate {g}->{} at (t{t},j{j}), rg {rg}->{} (window 2^{gshift}), a -> table[g-1], h {h} unchanged", g - 1, rg + (1i64 << gshift));
                }
            }
            panic!("no gate position admits the alternative")
        }
        Alt::Up => {
            for t in 0..sh.tokens {
                for j in 0..sh.hidden {
                    let pos = t * sh.f_pad + j;
                    let (a, u) = (wit.planes[ids.at(A_A16)][pos], wit.planes[ids.at(A_U16)][pos]);
                    let ru = get_limbs(wit, low, L::Ru, pos);
                    if a != 0 || u <= -32768 || ru + (1i64 << p.up) >= 1i64 << 16 {
                        continue;
                    }
                    wit.planes[ids.at(A_U16)][pos] = u - 1;
                    set_limbs(wit, low, L::Up, pos, u - 1 + 32768);
                    set_limbs(wit, low, L::Ru, pos, ru + (1i64 << p.up));
                    return format!("up {u}->{} at (t{t},j{j}) where a = 0, ru {ru}->{} (window 2^{})", u - 1, ru + (1i64 << p.up), p.up);
                }
            }
            panic!("no up position admits the alternative")
        }
        Alt::Down => {
            let cap = 1i64 << (8 * low.count(L::Rd));
            for t in 0..sh.tokens {
                for i in 0..sh.width {
                    let pos = t * sh.d_pad + i;
                    let (z, x2) = (wit.planes[ids.at(A_Z16)][pos], wit.planes[ids.at(A_X2)][pos]);
                    let rd = get_limbs(wit, low, L::Rd, pos);
                    if z <= -32768 || x2 <= -32768 || rd + (1i64 << p.down) >= cap {
                        continue;
                    }
                    wit.planes[ids.at(A_Z16)][pos] = z - 1;
                    set_limbs(wit, low, L::Z, pos, z - 1 + 32768);
                    set_limbs(wit, low, L::Rd, pos, rd + (1i64 << p.down));
                    wit.planes[ids.at(A_X2)][pos] = x2 - 1;
                    set_limbs(wit, low, L::X2, pos, x2 - 1 + 32768);
                    return format!("down z {z}->{} and output x2 {x2}->{} at (t{t},i{i}), rd {rd}->{} (window 2^{})", z - 1, x2 - 1, rd + (1i64 << p.down), p.down);
                }
            }
            panic!("no down position admits the alternative")
        }
        Alt::MaskedScore => {
            let tp = sh.t_pad;
            for h in 0..sh.q_heads {
                for t in 0..sh.tokens {
                    for j in (t + 1)..sh.tokens {
                        let pos = (sh.head_slot(h) * tp + t) * tp + j;
                        let s = wit.planes[ids.at(A_S8)][pos];
                        let rs = get_limbs(wit, low, L::Rs, pos);
                        if s <= -127 || rs + (1i64 << p.score) >= 1i64 << 24 {
                            continue;
                        }
                        wit.planes[ids.at(A_S8)][pos] = s - 1;
                        set_limbs(wit, low, L::Rs, pos, rs + (1i64 << p.score));
                        return format!("masked score {s}->{} at (h{h},t{t},j{j}), rs {rs}->{} (window 2^{})", s - 1, rs + (1i64 << p.score), p.score);
                    }
                }
            }
            panic!("no masked score admits the alternative")
        }
        Alt::PadAct => {
            assert!(sh.f_pad > sh.hidden, "the fixture must pad Dom::F");
            let pos = 3 * sh.f_pad + sh.hidden + 5;
            wit.planes[ids.at(A_G8)][pos] = 1;
            wit.planes[ids.at(A_A16)][pos] = data.scaled_tables()[0][2049];
            format!("padded F position (t3, j{}): (gate 1, group-0 table[1] = {}) instead of (0, 0)", sh.hidden + 5, data.scaled_tables()[0][2049])
        }
        Alt::GroupSwap => unreachable!(),
    }
}

#[test]
#[ignore = "reviewer R13: self-consistent alternative witnesses at four windows, pad and group swaps"]
fn rv13_alternative_witnesses_are_rejected() {
    for (name, dd) in [("rv-generic-h24", false), ("rv-generic-h24", true), ("rv-generic-low", false)] {
        let cs = load(name, dd);
        let honest = witness::build_for_block(&cs.sh, &cs.layer.blk, &cs.x).unwrap();
        let lay = Layout::for_shape(&cs.sh).unwrap();
        super::protocol::check_lookup_misses(&cs.sh, &lay, &cs.layer.blk, &honest).unwrap();
        for alt in [Alt::Gate, Alt::Up, Alt::Down, Alt::MaskedScore, Alt::PadAct] {
            let mut w = honest.clone();
            let what = mutate(&cs, &mut w, alt);
            let misses = super::protocol::check_lookup_misses(&cs.sh, &lay, &cs.layer.blk, &w);
            let (r, n) = run_case(&cs, &cs.layer.blk, &cs.layer.blk, w, true, false);
            assert!(r.is_err(), "{name} dd={dd} {alt:?} ACCEPTED: {what}");
            eprintln!("RV13-ALT {name} dd={dd} {alt:?}: {what}; pre-proof lookup check {}; receipt {n} B; verifier: {}",
                if misses.is_err() { "misses (cheating prover skips it)" } else { "hits" }, r.unwrap_err());
        }
        // two channels in different groups swap their PUBLIC group ids
        let a = cs.layer.blk.accuracy().unwrap();
        let mut ids2 = a.group_ids().to_vec();
        assert_ne!(ids2[0], ids2[1]);
        ids2.swap(0, 1);
        let swapped = super::accuracy_public::AccuracyPublic::new(a.stack(), a.geometry(), a.base(), a.member(),
            a.multipliers().clone(), a.groups().to_vec(), ids2, a.raw_tables().to_vec()).unwrap();
        assert_eq!(swapped.folds().gate.shift, a.folds().gate.shift);
        let blk2 = cs.layer.blk.clone().with_accuracy(swapped);
        assert_ne!(blk2.digest(), cs.layer.blk.digest(), "the group-id swap must move the block digest");
        let wrong = witness::build_for_block(&cs.sh, &blk2, &cs.x).unwrap();
        let ids = Ids::new(&cs.sh).unwrap();
        let differ = (0..cs.sh.size(Dom::F)).filter(|&i| wrong.planes[ids.at(A_A16)][i] != honest.planes[ids.at(A_A16)][i]
            || wrong.planes[ids.at(A_G8)][i] != honest.planes[ids.at(A_G8)][i]).count();
        let (r, n) = run_case(&cs, &cs.layer.blk, &cs.layer.blk, wrong.clone(), true, false);
        assert!(r.is_err(), "{name} dd={dd}: swapped-group witness accepted under the original statement");
        eprintln!("RV13-ALT {name} dd={dd} GroupSwap(witness): ids of channels 0/1 swapped in the witness only, {differ} F words differ, receipt {n} B; verifier: {}", r.unwrap_err());
        // the swapped statement proves honestly and verifies, and neither statement accepts the other's receipt
        let (r, _) = run_case(&cs, &blk2, &blk2, wrong.clone(), false, false);
        r.unwrap_or_else(|e| panic!("{name}: the honest swapped-statement receipt was refused: {e}"));
        let (r, _) = run_case(&cs, &blk2, &cs.layer.blk, wrong, true, false);
        assert!(r.is_err(), "{name} dd={dd}: a swapped-statement receipt verified under the original statement");
        let (r, _) = run_case(&cs, &cs.layer.blk, &blk2, honest.clone(), false, false);
        assert!(r.is_err(), "{name} dd={dd}: an original receipt verified under the swapped statement");
        eprintln!("RV13-ALT {name} dd={dd} GroupSwap(statement): swapped statement verifies its own honest receipt; cross-verification refused both ways");
    }
}

#[test]
#[ignore = "reviewer R13: trained-door refusals of doctored exports"]
fn rv13_doctored_exports_are_refused_at_the_door() {
    let first_err = |name: &str| -> Result<(), String> {
        let ex = TrainedExport::load(&rv(name))?;
        let c = ex.run_constants(&[0])?;
        let seed = ex.shape_for(&c)?;
        let layer = ex.load_layer(&seed, &c, 0, false)?;
        let sh = layer.record.shape_at(&seed)?;
        layer.blk.check_for_shape(&sh)?;
        Ok(())
    };
    for (name, want) in [("rv-w128", "symmetric int8"), ("rv-gamma128", "symmetric int8"), ("rv-scaled-act", "derived by the verifier"),
        ("rv-act-doctored", "not the declared generated member"), ("rv-five-groups", "silu_groups"), ("rv-std-08", "registry"),
        ("rv-mg-zero", "narrow"), ("rv-mo-257", "narrow"), ("rv-legacy-names-r13", "legacy export cannot select R13")] {
        let e = first_err(name).err().unwrap_or_else(|| panic!("{name}: the doctored export LOADED"));
        eprintln!("RV13-DOOR {name}: refused: {e}");
        assert!(e.contains(want), "{name}: refused for another reason than `{want}`: {e}");
    }
    first_err("rv-group-swap").unwrap();
    let a = load("rv-generic-h24", false);
    let b = load("rv-group-swap", false);
    assert_ne!(a.layer.record.block_digest, b.layer.record.block_digest);
    eprintln!("RV13-DOOR rv-group-swap: loads (a valid public change) and moves the block digest {} -> {}",
        super::trained_block::hex(&a.layer.record.block_digest), super::trained_block::hex(&b.layer.record.block_digest));
}

#[test]
#[ignore = "reviewer R13: native lookup windows of the widened words, the score and the gate"]
fn rv13_native_lookup_windows() {
    for name in ["rv-generic-h24", "rv-generic-low"] {
        let cs = load(name, false);
        let ids = Ids::new(&cs.sh).unwrap();
        let low = ids.accuracy().unwrap();
        let p = cs.sh.accuracy_precision().unwrap();
        let g = cs.sh.accuracy_gate_shift;
        let all: Vec<(Dom, Vec<Lk>)> = [Dom::L, Dom::D, Dom::Q, Dom::Kv, Dom::S, Dom::F]
            .into_iter().map(|d| (d, low.lookups(d, &p, g, cs.sh.wrho_s).unwrap())).collect();
        // every widened word: two plain byte limbs, no scaled pin (so the word set is exactly [-32768, 32767])
        for role in [L::Y, L::Ym, L::Q, L::Qr, L::O, L::K, L::V, L::Kr] {
            assert_eq!(low.count(role), 2, "{role:?}");
            for k in 0..2 {
                let id = low.limb(role, k);
                let uses: Vec<&Lk> = all.iter().flat_map(|(_, v)| v.iter()).filter(|l| l.terms.iter().any(|t| t.0 == id)).collect();
                assert_eq!(uses.len(), 1, "{role:?}[{k}]");
                assert_eq!((uses[0].terms.clone(), uses[0].cst), (vec![(id, 1)], 0), "{role:?}[{k}] is not a plain byte lookup");
            }
        }
        // the score word: exactly the two symmetric lookups s+127, 127-s
        let s8 = ids.at(A_S8);
        let s_uses: Vec<&Lk> = all.iter().flat_map(|(_, v)| v.iter()).filter(|l| l.terms.iter().any(|t| t.0 == s8)).collect();
        assert_eq!(s_uses.len(), 2);
        let admitted: Vec<i64> = (-200..200).filter(|&s| s_uses.iter().all(|l| (0..256).contains(&(l.cst + l.terms[0].1 * s)))).collect();
        assert_eq!((admitted[0], *admitted.last().unwrap(), admitted.len()), (-127, 127, 255));
        // remainder pins: a remainder r is admitted iff r < 2^shift
        for (role, shift) in [(L::Rg, g), (L::Ru, p.up), (L::Rd, p.down), (L::Rs, p.score), (L::Rao, p.ao), (L::Rq, p.q), (L::Rk, p.k), (L::Rv, p.v), (L::Ro, p.pv)] {
            let n = low.count(role);
            let top = low.limb(role, n - 1);
            let pins: Vec<&Lk> = all.iter().flat_map(|(_, v)| v.iter()).filter(|l| l.terms.len() == 1 && l.terms[0].0 == top && l.terms[0].1 != 1).collect();
            let window = |r: i64| -> bool {
                let t = r >> (8 * (n - 1));
                t < 256 && pins.iter().all(|l| (0..256).contains(&(l.terms[0].1 * t)))
            };
            let max = (0..1i64 << (8 * n)).rev().step_by(1).find(|&r| window(r)).unwrap();
            // the largest admitted remainder must be 2^shift - 1 (exact window), up to the low limbs
            assert_eq!(max >> (8 * (n - 1)), ((1i64 << shift) - 1) >> (8 * (n - 1)), "{role:?}: window is not 2^{shift}");
            eprintln!("RV13-WINDOW {name} {role:?}: {n} limbs, pin {:?}, admitted top limb <= {} (2^{shift} window)", pins.iter().map(|l| l.terms[0].1).collect::<Vec<_>>(), max >> (8 * (n - 1)));
        }
        eprintln!("RV13-WINDOW {name}: 8 widened words are two plain bytes each ([-32768, 32767]); score admits exactly [-127, 127]");
    }
}

#[test]
#[ignore = "reviewer R13: actual Shieldstral L00/L25 native witnesses (one checkpoint stream)"]
fn rv13_shieldstral_actual_layers_native_witness() {
    let root = PathBuf::from(std::env::var("HL_R13_SHIELDSTRAL_EXPORT").expect("actual export"));
    let t0 = std::time::Instant::now();
    let ex = TrainedExport::load(&root).unwrap();
    eprintln!("RV13-SHIELD export loaded (checkpoint authenticated, tied tables derived) in {:.1} s", t0.elapsed().as_secs_f64());
    let layers: Vec<u32> = (0..26).collect();
    let c = ex.run_constants(&layers).unwrap();
    let seed = ex.shape_for(&c).unwrap();
    for i in [0u32, 25] {
        let input = std::fs::read(std::env::var(format!("RV13_SHIELD_INPUT_L{i:02}")).expect("reviewer input")).unwrap();
        let x: Vec<i16> = input.chunks_exact(2).map(|b| i16::from_le_bytes([b[0], b[1]])).collect();
        assert_eq!(x.len(), seed.tokens * seed.width);
        let layer = ex.load_layer(&seed, &c, i, false).unwrap();
        let sh = layer.record.shape_at(&seed).unwrap();
        let a = layer.blk.accuracy().unwrap();
        let groups: Vec<(i32, i32)> = a.groups().iter().map(|g| (g.e_in, g.e_out)).collect();
        let wit = witness::build_for_block(&sh, &layer.blk, &x).unwrap_or_else(|e| panic!("L{i}: builder refused the reviewer input: {e}"));
        dump(&sh, &wit, &evidence().join(format!("shield-L{i:02}.native.tsv")));
        eprintln!("RV13-SHIELD L{i}: groups {groups:?}, G {}, product shift {}, multipliers {:?}, witness dumped",
            a.folds().gate.shift, a.folds().product.shift, {
                let mut m: Vec<u64> = a.folds().product.multipliers.clone(); m.sort(); m.dedup(); m });
    }
}

/// Sol's CLI calibration controls build their verifier statement at a LEGACY
/// shape (`geometry.shape_at`), so at R13 profiles they are refused by the
/// gate-denominator door before any receipt byte is read. This rebuilds each
/// control at the R13 shape, with the block's R13 public data re-derived for the
/// moved base, and records which stage refuses it.
#[test]
#[ignore = "reviewer R13: calibration controls at R13 shapes reach the receipt"]
fn rv13_calibration_controls_reach_the_receipt() {
    use super::shape::NormCalibration;
    for name in ["rv-generic-h24", "rv-generic-low"] {
        let cs = load(name, false);
        let wit = witness::build_for_block(&cs.sh, &cs.layer.blk, &cs.x).unwrap();
        let ids = Ids::new(&cs.sh).unwrap();
        let input: Vec<i16> = wit.planes[ids.at(A_X)].iter().map(|&v| v as i16).collect();
        let output: Vec<i16> = wit.planes[ids.at(A_X2)].iter().map(|&v| v as i16).collect();
        let context = [79u8; 32];
        let (expected, owners) = prepare_endpoints(IoSpec::new_shaped(&cs.seed, context, 0, 0).unwrap(), &input, &output).unwrap();
        let blocks = vec![cs.layer.blk.clone()];
        let model = cs.ex.statement(&cs.seed, &cs.c, &[&cs.layer]).unwrap();
        let st = RunStatement::new_bound(RunShape::accuracy(cs.seed.clone(), 1).unwrap(), context, expected.clone(), &blocks, &[(0, 0)], &model).unwrap();
        let mut segs = Vec::new();
        let mut src = One(Some(wit));
        run::prove_run(&st, &blocks, &mut src, owners, &mut |_, b| { segs.push(b); Ok(()) }).unwrap();
        run::verify_run(&st, &blocks, &segs).unwrap();
        let c = cs.c.cal;
        let nudge = |v: u32, lo: u32, hi: u32| (if v < hi { v + 1 } else { v - 1 }).clamp(lo, hi);
        let mut receipt_refusals = 0;
        for (what, v) in [
            ("norm_tn - 1", NormCalibration { tn: c.tn - 1, ..c }),
            ("norm_cn_a + 1", NormCalibration { cn_a: c.cn_a + 1, ..c }),
            ("norm_cn_m + 1", NormCalibration { cn_m: c.cn_m + 1, ..c }),
            ("norm_ceps + 1", NormCalibration { ceps: c.ceps + 1, ..c }),
            ("sh_ao +-1", NormCalibration { sh_ao: if c.sh_ao < 8 { c.sh_ao + 1 } else { c.sh_ao - 1 }, ..c }),
            ("sh_qkv +-1", NormCalibration { sh_qkv: nudge(c.sh_qkv, 2, 8), ..c }),
            ("sh_s +-1", NormCalibration { sh_s: nudge(c.sh_s, 5, 8), ..c }),
            ("sh_o +-1", NormCalibration { sh_o: nudge(c.sh_o, 9, 13), ..c }),
            ("sh_g +-1", NormCalibration { sh_g: nudge(c.sh_g, 1, 8), ..c }),
            ("sh_h +-1", NormCalibration { sh_h: nudge(c.sh_h, 13, 16), ..c }),
            ("sh_z +-1", NormCalibration { sh_z: nudge(c.sh_z, 3, 8), ..c }),
        ] {
            let built = (|| -> Result<(RunStatement, Vec<BlockPublic>), String> {
                let a = cs.layer.blk.accuracy().unwrap();
                let seed2 = Shape::accuracy_trained(cs.seed.profile, &v, cs.seed.f_e, 17)?;
                let data2 = super::accuracy_public::AccuracyPublic::new(a.stack(), a.geometry(), seed2.accuracy_base(), a.member(),
                    a.multipliers().clone(), a.groups().to_vec(), a.group_ids().to_vec(), a.raw_tables().to_vec())?;
                let blk2 = cs.layer.blk.clone().with_accuracy(data2);
                let mut rec2 = super::trained_statement::LayerRecord::of_block(0, &blk2, cs.layer.record.source_tensors.clone());
                rec2.manifest_sha256 = cs.layer.manifest_sha256;
                rec2.silu_member = cs.layer.record.silu_member;
                rec2.exp_e_s = cs.layer.record.exp_e_s;
                let c2 = super::trained_block::Constants { cal: v, ..cs.c.clone() };
                let st2 = cs.ex.statement_of_records(&seed2, &c2, vec![rec2])?;
                let blocks2 = vec![blk2];
                let r2 = RunStatement::new_bound(RunShape::accuracy(seed2, 1)?, context, expected.clone(), &blocks2, &[(0, 0)], &st2)?;
                Ok((r2, blocks2))
            })();
            match built {
                Err(e) => eprintln!("RV13-CONTROL {name} {what}: not constructible at the R13 door (no receipt read): {e}"),
                Ok((r2, blocks2)) => {
                    let r = run::verify_run(&r2, &blocks2, &segs);
                    assert!(r.is_err(), "{name} {what}: the receipt VERIFIED under a moved calibration");
                    receipt_refusals += 1;
                    eprintln!("RV13-CONTROL {name} {what}: receipt refused by the verifier: {}", r.unwrap_err());
                }
            }
        }
        assert!(receipt_refusals >= 8, "{name}: too few controls reached the receipt ({receipt_refusals})");
        eprintln!("RV13-CONTROL {name}: {receipt_refusals} of 11 calibration controls reached and refused the receipt at the R13 shape");
    }
}
