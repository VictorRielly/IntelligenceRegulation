//! **INDEPENDENT ADVERSARIAL REVIEW OF STAGE 20** (the repair of finding
//! S19-F1), 2026-09-20. Report:
//! `docs/zkmatrix-poc/ZK60_BLOCK125M_S20_FIX_REVIEW.md`.
//!
//! The reviewer wrote the identity out on paper from `layout.rs`'s domain
//! comments before reading any stage-20 test, and then wrote the checks below.
//! They are deliberately NOT the lane's own independent check
//! (`dense_tests::the_two_bilinear_identities_hold_*`), which evaluates the
//! paper formula with plain loops and never touches `argument::define`. These
//! go the OTHER way: they drive the REAL `argument::define`, take the real
//! `Tab` list it built — the real `Coord` lists, the real `Tab::Eq` point and
//! start, the real slot closure — and check that the polynomial the module
//! actually sums is the multilinear extension the slot's HOST demands.
//!
//! That is the half the lane's check cannot see. A correct paper identity
//! implemented with one coordinate segment in the wrong place, an `eq` at the
//! wrong `start`, a key factor reading the group at variables of its own, or a
//! closure that multiplies the wrong two tables would pass the lane's test and
//! fail these.
//!
//! Everything here is algebraic in the PLANE CONTENTS, so the `A` buffer is
//! filled with a fixed pseudo-random stream rather than a witness: the
//! statement "the slot's sum is the extension of the pointwise product" has to
//! hold for arbitrary plane contents, and random contents are a far stronger
//! test than a witness that happens to be degenerate (which is exactly how
//! S19-F1 survived nineteen stages).

use super::argument::{define, Coord, Ctx, Points, Priv, Tab};
use super::layout::*;
use super::protocol::{prove_inner_at, verify_inner_at};
use super::shape::Shape;
use super::witness::{self, Witness};
use super::*;
use crate::field::{Fp, Fp2};

// ---------------------------------------------------------------- tiny helpers

/// SplitMix64, so nothing here reads OS randomness or the module's own RNG.
struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }
    fn fp(&mut self) -> Fp {
        Fp::new(self.next() >> 2)
    }
}

/// `eq(point, x)` with `x`'s bits read MOST SIGNIFICANT FIRST — written out
/// rather than calling `mle::eq_table_msb`, so the check shares no code with
/// the thing under review.
fn eq_msb(point: &[Fp2], x: usize) -> Fp2 {
    let n = point.len();
    let mut acc = Fp2::ONE;
    for (k, p) in point.iter().enumerate() {
        let b = (x >> (n - 1 - k)) & 1;
        acc = acc.mul(if b == 1 { *p } else { Fp2::ONE.sub(*p) });
    }
    acc
}

/// the multilinear extension of `vals` (indexed MSB-first) at `point`
fn mle(vals: &[Fp2], point: &[Fp2]) -> Fp2 {
    assert_eq!(vals.len(), 1usize << point.len());
    let mut acc = Fp2::ZERO;
    for (x, v) in vals.iter().enumerate() {
        acc = acc.add(eq_msb(point, x).mul(*v));
    }
    acc
}

/// One committed plane, lifted out of the flat `A` buffer as field values.
fn plane_of(data: &[Fp], off: usize, log: usize) -> Vec<Fp2> {
    (0..1usize << log).map(|i| Fp2::from_base(data[off + i])).collect()
}

// ---------------------------------------------------------- the reviewer's table builder

/// The reviewer's own reading of what a `Tab` MEANS over a slot's cube of
/// `n_vars` variables. Independent of `argument::table_of`, which is private
/// to that module anyway.
///
/// * `Tab::Eq { point, start }` is `eq(point, x[start .. start + |point|])`,
///   constant in every other variable — coordinates MSB-first.
/// * `Tab::Pub(v)` is the table itself.
/// * `Tab::Priv(p)` is `plane~(c_0(x), .., c_{log-1}(x))`, the plane's
///   multilinear extension evaluated at the point the coordinate list builds
///   from the slot's variables: `Rho(k)` is variable `k` (the `k`-th most
///   significant of the slot's `n_vars`), `Flip(k)` is `1 -` that, `Fixed(f)`
///   is the constant `f`.
fn my_table(t: &Tab, n_vars: usize, a: &[Fp]) -> Vec<Fp2> {
    let n = 1usize << n_vars;
    match t {
        Tab::Eq { point, start } => {
            let shift = n_vars - start - point.len();
            (0..n).map(|x| eq_msb(point, (x >> shift) & ((1usize << point.len()) - 1))).collect()
        }
        Tab::Pub(v) => {
            assert_eq!(v.len(), n, "a public table is not the slot's cube");
            v.clone()
        }
        Tab::Priv(p) => {
            assert_eq!(p.cm, super::argument::Cm::A, "this reviewer's builder only reads the A commitment");
            assert_eq!(p.slices.len(), 1);
            let (off, coef) = p.slices[0];
            let vals: Vec<Fp2> = (0..1usize << p.log).map(|i| coef.mul_base(a[off + i])).collect();
            (0..n)
                .map(|x| {
                    let point: Vec<Fp2> = p
                        .coords
                        .iter()
                        .map(|c| match c {
                            Coord::Rho(k) => Fp2::from_u64(((x >> (n_vars - 1 - k)) & 1) as u64),
                            Coord::Flip(k) => Fp2::from_u64((1 - ((x >> (n_vars - 1 - k)) & 1)) as u64),
                            Coord::Fixed(f) => *f,
                        })
                        .collect();
                    mle(&vals, &point)
                })
                .collect()
        }
    }
}

/// `sum_x poly(tables(x))` — the quantity the slot's sumcheck claims.
fn slot_total(def: &super::argument::SlotDef, n_vars: usize, a: &[Fp]) -> Fp2 {
    let tabs: Vec<Vec<Fp2>> = def.tabs.iter().map(|t| my_table(t, n_vars, a)).collect();
    let mut acc = Fp2::ZERO;
    let mut row = vec![Fp2::ZERO; tabs.len()];
    for x in 0..1usize << n_vars {
        for (r, t) in row.iter_mut().zip(tabs.iter()) {
            *r = t[x];
        }
        acc = acc.add((def.poly)(&row));
    }
    acc
}

// ---------------------------------------------------------- the statement, on paper

/// the key-value group of padded head slot `h`: its TOP `lkv` bits (C-1)
fn group_of(sh: &Shape, h: usize) -> usize {
    h >> sh.log_slots_per_kv_group()
}

/// `score[h, t, j] = sum_c q[t, h, c] * k[j, g(h), c]`, over the FULL padded
/// `Dom::S = (h, t, j)` cube. The reviewer's reading of the domain comments in
/// `layout.rs` (`Dom::Q = (t, slot, c)`, `Dom::Kv = (j, group, c)`).
fn score_plane(sh: &Shape, q: &[Fp2], kk: &[Fp2]) -> Vec<Fp2> {
    let (tp, hp, dh, kv) = (sh.t_pad, sh.h_pad, sh.head_dim, sh.kv_heads);
    let mut out = vec![Fp2::ZERO; sh.size(Dom::S)];
    for h in 0..hp {
        let g = group_of(sh, h);
        for t in 0..tp {
            for j in 0..tp {
                let mut acc = Fp2::ZERO;
                for c in 0..dh {
                    acc = acc.add(q[(t * hp + h) * dh + c].mul(kk[(j * kv + g) * dh + c]));
                }
                out[(h * tp + t) * tp + j] = acc;
            }
        }
    }
    out
}

/// `out[t, h, i] = sum_s p[h, t, s] * v[s, g(h), i]`, over the FULL padded
/// `Dom::Q = (t, slot, i)` cube.
fn out_plane(sh: &Shape, p: &[Fp2], v: &[Fp2]) -> Vec<Fp2> {
    let (tp, hp, dh, kv) = (sh.t_pad, sh.h_pad, sh.head_dim, sh.kv_heads);
    let mut out = vec![Fp2::ZERO; sh.size(Dom::Q)];
    for t in 0..tp {
        for h in 0..hp {
            let g = group_of(sh, h);
            for i in 0..dh {
                let mut acc = Fp2::ZERO;
                for s in 0..tp {
                    acc = acc.add(p[(h * tp + t) * tp + s].mul(v[(s * kv + g) * dh + i]));
                }
                out[(t * hp + h) * dh + i] = acc;
            }
        }
    }
    out
}

/// **THE PRE-STAGE-20 FORMULA**, written out so the checks below have teeth:
/// the product of the two extensions at a SHARED FIXED group point,
/// `sum_c Q~(r_t, r_h, c) K~(r_j, r_g, c)`.
fn old_score_formula(sh: &Shape, q: &[Fp2], kk: &[Fp2], r_h: &[Fp2], r_t: &[Fp2], r_j: &[Fp2]) -> Fp2 {
    let (tp, hp, dh, kv) = (sh.t_pad, sh.h_pad, sh.head_dim, sh.kv_heads);
    let lkv = kv.trailing_zeros() as usize;
    let r_g = &r_h[..lkv];
    let mut acc = Fp2::ZERO;
    for c in 0..dh {
        let mut qe = Fp2::ZERO;
        for t in 0..tp {
            for h in 0..hp {
                qe = qe.add(eq_msb(r_t, t).mul(eq_msb(r_h, h)).mul(q[(t * hp + h) * dh + c]));
            }
        }
        let mut ke = Fp2::ZERO;
        for j in 0..tp {
            for g in 0..kv {
                ke = ke.add(eq_msb(r_j, j).mul(eq_msb(r_g, g)).mul(kk[(j * kv + g) * dh + c]));
            }
        }
        acc = acc.add(qe.mul(ke));
    }
    acc
}

fn old_pv_formula(sh: &Shape, p: &[Fp2], v: &[Fp2], r_h: &[Fp2], r_t: &[Fp2], r_i: &[Fp2]) -> Fp2 {
    let (tp, hp, dh, kv) = (sh.t_pad, sh.h_pad, sh.head_dim, sh.kv_heads);
    let lkv = kv.trailing_zeros() as usize;
    let r_g = &r_h[..lkv];
    let mut acc = Fp2::ZERO;
    for s in 0..tp {
        let mut pe = Fp2::ZERO;
        for h in 0..hp {
            for t in 0..tp {
                pe = pe.add(eq_msb(r_h, h).mul(eq_msb(r_t, t)).mul(p[(h * tp + t) * tp + s]));
            }
        }
        let mut ve = Fp2::ZERO;
        for g in 0..kv {
            for i in 0..dh {
                ve = ve.add(eq_msb(r_g, g).mul(eq_msb(r_i, i)).mul(v[(s * kv + g) * dh + i]));
            }
        }
        acc = acc.add(pe.mul(ve));
    }
    acc
}

// ---------------------------------------------------------- the driver

struct Built {
    /// the two slot totals the module's own definition sums to
    score: Fp2,
    pv: Fp2,
    /// the extension the HOST demands, from the reviewer's own product planes
    want_score: Fp2,
    want_pv: Fp2,
    /// the pre-stage-20 formula at the same points
    old_score: Fp2,
    old_pv: Fp2,
}

/// Drive the REAL `argument::define` over the whole slot order at `sh` with a
/// pseudo-random `A` buffer, and return the four field elements the identity
/// is a statement about.
///
/// `degenerate`: make every key-value group of `A_KR8` and `A_V8` carry the
/// SAME data, which is the regime in which the old formula happens to be
/// right — the condition that hid S19-F1.
fn build(sh: &Shape, seed: u64, degenerate: bool) -> Built {
    let lay = Layout::for_shape(sh).unwrap_or_else(|e| panic!("{}: layout: {e}", sh.name));
    let ids = lay.ids();
    let (public, ff, _) = super::grow_tests::tame_case(sh);
    let ctx = Ctx { accuracy:None,
        lay: &lay,
        public: &public,
        ff: &ff,
        alpha: Fp2::from_u64(7).add(Fp2::U),
        beta: Fp2::from_u64(11),
        g_u8: Fp2::from_u64(13),
        g_exp: Fp2::from_u64(17),
        g_act: Fp2::from_u64(19),
        g_dd: Fp2::from_u64(23),
    };
    // a pseudo-random A buffer: the identity is algebraic in the contents
    let n = 1usize << sh.log_cols;
    let mut r = Rng(seed);
    let mut a: Vec<Fp> = (0..lay.a_rows * n).map(|_| r.fp()).collect();
    let (kv, dh) = (sh.kv_heads, sh.head_dim);
    if degenerate {
        // copy group 0's words over every other group, on both key-value planes
        for toy in [A_KR8, A_V8] {
            let off = lay.a_off[ids.at(toy)];
            for x in 0..sh.t_pad {
                for g in 1..kv {
                    for c in 0..dh {
                        a[off + (x * kv + g) * dh + c] = a[off + (x * kv) * dh + c];
                    }
                }
            }
        }
    }
    let qr8 = plane_of(&a, lay.a_off[ids.at(A_QR8)], sh.log(Dom::Q));
    let kr8 = plane_of(&a, lay.a_off[ids.at(A_KR8)], sh.log(Dom::Kv));
    let p8 = plane_of(&a, lay.a_off[ids.at(A_P)], sh.log(Dom::S));
    let v8 = plane_of(&a, lay.a_off[ids.at(A_V8)], sh.log(Dom::Kv));

    let mut tr = crate::transcript::Transcript::new(sh.profile.as_bytes());
    let mut pts = Points::default();
    let slots = sh.slots();
    let (mut score, mut pv) = (Fp2::ZERO, Fp2::ZERO);
    let (mut ps, mut po) = (Vec::new(), Vec::new());
    for s in 0..N_SLOTS {
        let def = define(s, &ctx, &mut pts, &mut tr).unwrap_or_else(|e| panic!("{}: slot {s}: {e}", sh.name));
        if s == SC_SCORE {
            score = slot_total(&def, slots[s].0, &a);
            ps = pts.p_s().to_vec();
        }
        if s == SC_PV {
            pv = slot_total(&def, slots[s].0, &a);
            po = pts.p_o().to_vec();
            break;
        }
    }
    // `p_s` is `(r_h, r_t, r_j)` on `Dom::S`; `p_o` is `(r_t, r_h, r_i)` on `Dom::Q`
    let (lt, lh, ldh) = (sh.t_pad.trailing_zeros() as usize, sh.h_pad.trailing_zeros() as usize, dh.trailing_zeros() as usize);
    assert_eq!(ps.len(), lh + 2 * lt, "p_s is not a Dom::S point");
    assert_eq!(po.len(), lt + lh + ldh, "p_o is not a Dom::Q point");
    let (sh_r_h, sh_r_t, sh_r_j) = (&ps[..lh], &ps[lh..lh + lt], &ps[lh + lt..]);
    let (pv_r_t, pv_r_h, pv_r_i) = (&po[..lt], &po[lt..lt + lh], &po[lt + lh..]);
    Built {
        score,
        pv,
        want_score: mle(&score_plane(sh, &qr8, &kr8), &ps),
        want_pv: mle(&out_plane(sh, &p8, &v8), &po),
        old_score: old_score_formula(sh, &qr8, &kr8, sh_r_h, sh_r_t, sh_r_j),
        old_pv: old_pv_formula(sh, &p8, &v8, pv_r_h, pv_r_t, pv_r_i),
    }
}

/// A SYNTHETIC geometry with FOUR key-value heads, a group of three true query
/// heads and one padded head slot per group (padded slots `{3, 7, 11, 15}`,
/// 125M's own head geometry). Chosen so that no domain is lifted by P-3, which
/// the two bilinear coordinate lists (they are written at the NATURAL log of
/// `Dom::Kv`) require.
fn kv4() -> Shape {
    Shape::new(
        "review: synthetic 4-KV-head geometry (T6 / d96 / f24, 12 heads of 8 over 4 KV heads)",
        "hashline-zk-mr1/private-block-s20-review-kv4/1",
        6,
        96,
        24,
        12,
        8,
        4,
        8,
        4,
        9,
        9,
        None,
        None,
        None,
        None,
    )
    .expect("the synthetic 4-KV-head shape is well formed")
}

// ---------------------------------------------------------------- F-tests

/// **THE CENTRAL CHECK.** At every shape, for both bilinear slots, the sum the
/// module's OWN definition takes over its OWN cube is exactly the multilinear
/// extension, at the slot's published claim point, of the pointwise product
/// the slot's host demands. Nothing is assumed about the coordinate lists: they
/// are read out of the `SlotDef` the production code built.
#[test]
fn the_bilinear_slot_definitions_sum_to_the_hosts_extension() {
    for sh in [Shape::toy(), Shape::rung_g(), kv4()] {
        for seed in [0x5115_0020u64, 0x0BAD_C0DE, 0x1234_5678] {
            let b = build(&sh, seed, false);
            assert_eq!(b.score, b.want_score, "{} seed {seed:#x}: SC_SCORE's definition is not the host's extension", sh.name);
            assert_eq!(b.pv, b.want_pv, "{} seed {seed:#x}: SC_PV's definition is not the host's extension", sh.name);
        }
        eprintln!("S20-REVIEW identity through define: OK at {}", sh.name);
    }
}

/// **THE CHECK HAS TEETH.** On generic plane contents at a shape with more
/// than one key-value head the PRE-stage-20 formula disagrees with the host's
/// extension — so the test above is not vacuous — and it AGREES both at one
/// key-value head (the frozen toy, where the repair is a no-op) and on a
/// group-degenerate witness (which is why nineteen stages of green tests never
/// saw S19-F1).
#[test]
fn the_pre_stage_20_formula_disagrees_exactly_where_the_defect_was() {
    for sh in [Shape::rung_g(), kv4()] {
        let b = build(&sh, 0x5115_0020, false);
        assert_ne!(b.old_score, b.want_score, "{}: the old SC_SCORE formula already agreed, so there was no defect", sh.name);
        assert_ne!(b.old_pv, b.want_pv, "{}: the old SC_PV formula already agreed", sh.name);
        let d = build(&sh, 0x5115_0020, true);
        assert_eq!(d.old_score, d.want_score, "{}: the old SC_SCORE formula is wrong even on a degenerate witness", sh.name);
        assert_eq!(d.old_pv, d.want_pv, "{}: the old SC_PV formula is wrong even on a degenerate witness", sh.name);
        // and the repaired definition is right in BOTH regimes
        assert_eq!(d.score, d.want_score, "{}: the repaired SC_SCORE is wrong on a degenerate witness", sh.name);
        assert_eq!(d.pv, d.want_pv, "{}: the repaired SC_PV is wrong on a degenerate witness", sh.name);
    }
    // at ONE key-value head the two formulas are the same expression
    let t = build(&Shape::toy(), 0x5115_0020, false);
    assert_eq!(t.old_score, t.want_score, "the toy's old SC_SCORE formula");
    assert_eq!(t.old_pv, t.want_pv, "the toy's old SC_PV formula");
}

/// **THE SHAPE OF THE REPAIR, read off the real definition.** At `lkv > 0`
/// both bilinear slots must carry exactly ONE public factor, an `eq` at
/// `start = 0` over the LEADING `lkv` variables whose point is the head
/// challenge's OWN group bits (the top `lkv` entries of the claim point's head
/// segment) — not a point of its own — and both private factors must read the
/// group at the SAME variables `0 .. lkv`. At `lkv == 0` there must be no
/// public factor at all.
#[test]
fn the_group_eq_carries_the_head_challenges_own_group_bits() {
    for sh in [Shape::toy(), Shape::rung_g(), kv4()] {
        let lay = Layout::for_shape(&sh).expect("layout");
        let (public, ff, _) = super::grow_tests::tame_case(&sh);
        let ctx = Ctx { accuracy:None,
            lay: &lay,
            public: &public,
            ff: &ff,
            alpha: Fp2::from_u64(7).add(Fp2::U),
            beta: Fp2::from_u64(11),
            g_u8: Fp2::from_u64(13),
            g_exp: Fp2::from_u64(17),
            g_act: Fp2::from_u64(19),
            g_dd: Fp2::from_u64(23),
        };
        let mut tr = crate::transcript::Transcript::new(sh.profile.as_bytes());
        let mut pts = Points::default();
        let lkv = sh.kv_heads.trailing_zeros() as usize;
        let (lt, lh) = (sh.t_pad.trailing_zeros() as usize, sh.h_pad.trailing_zeros() as usize);
        for s in 0..N_SLOTS {
            let def = define(s, &ctx, &mut pts, &mut tr).expect("slot");
            if s != SC_SCORE && s != SC_PV {
                continue;
            }
            let eqs: Vec<(&Vec<Fp2>, usize)> = def.tabs.iter().filter_map(|t| if let Tab::Eq { point, start } = t { Some((point, *start)) } else { None }).collect();
            let pubs = def.tabs.iter().filter(|t| matches!(t, Tab::Pub(_))).count();
            assert_eq!(pubs, 0, "{} slot {s}: an unexpected public table", sh.name);
            if lkv == 0 {
                assert!(eqs.is_empty(), "{} slot {s}: the toy path grew a public factor", sh.name);
                continue;
            }
            assert_eq!(eqs.len(), 1, "{} slot {s}: not exactly one eq factor", sh.name);
            let (point, start) = eqs[0];
            assert_eq!(start, 0, "{} slot {s}: the group eq is not at start 0", sh.name);
            assert_eq!(point.len(), lkv, "{} slot {s}: the group eq is not lkv wide", sh.name);
            // the head challenge's own group bits, read off the claim point
            let want: Vec<Fp2> = if s == SC_SCORE { pts.p_s()[..lkv].to_vec() } else { pts.p_o()[lt..lt + lkv].to_vec() };
            assert_eq!(*point, want, "{} slot {s}: the group eq carries a point of its own", sh.name);
            // both private factors take the group at variables 0 .. lkv
            let privs: Vec<&Priv> = def.tabs.iter().filter_map(|t| if let Tab::Priv(p) = t { Some(p) } else { None }).collect();
            assert_eq!(privs.len(), 2, "{} slot {s}: not two private factors", sh.name);
            // A_QR8 is (t, slot, c) and A_KR8 is (j, group, c): the group sits
            // at offset lt in both. A_P is (slot, t, s) and A_V8 is (s, group,
            // i): at 0 and at lt.
            let offs: [usize; 2] = if s == SC_SCORE { [lt, lt] } else { [0, lt] };
            for (p, first) in privs.iter().zip(offs) {
                let got: Vec<usize> = (0..lkv)
                    .map(|k| match &p.coords[first + k] {
                        Coord::Rho(v) => *v,
                        c => panic!("{} slot {s}: group coordinate {k} is {c:?}", sh.name),
                    })
                    .collect();
                assert_eq!(got, (0..lkv).collect::<Vec<usize>>(), "{} slot {s}: a factor reads the group at variables of its own", sh.name);
            }
            // the within-group head is FIXED on the query side and absent on
            // the key side: the key factor must have exactly `lkv` free
            // coordinates outside its own inner axis
            let head_seg = if s == SC_SCORE { &pts.p_s()[..lh] } else { &pts.p_o()[lt..lt + lh] };
            let r_hj = &head_seg[lkv..];
            let fixed_of = |p: &Priv, at: usize| -> Vec<Fp2> {
                (0..lh - lkv)
                    .map(|k| match &p.coords[at + k] {
                        Coord::Fixed(f) => *f,
                        c => panic!("{} slot {s}: within-group coordinate {k} is {c:?}, not fixed", sh.name),
                    })
                    .collect()
            };
            let at = if s == SC_SCORE { lt + lkv } else { lkv };
            assert_eq!(fixed_of(privs[0], at), r_hj.to_vec(), "{} slot {s}: the query factor's within-group head is not the challenge's", sh.name);
        }
    }
}

/// **THE DECLARED SCHEDULE AGREES WITH WHAT THE DEFINITION BUILDS.** The
/// round count, the degree and the mask length of the two bilinear slots,
/// re-derived here from the axes alone, against `Shape::slots()` and
/// `Shape::slot_lengths()`; and the M-row budget `L + 256 <= 512`, which
/// `zk::mask_commit_tagged` enforces with a bare `assert!`.
#[test]
fn the_bilinear_schedule_and_the_mask_budget_are_what_the_axes_say() {
    for sh in [Shape::toy(), Shape::rung(), Shape::rung_g(), kv4(), Shape::m125()] {
        let lg = |v: usize| v.trailing_zeros() as usize;
        let lkv = lg(sh.kv_heads);
        let deg = if lkv > 0 { 3 } else { 2 };
        let want = [(SC_SCORE, lkv + lg(sh.head_dim)), (SC_PV, lkv + lg(sh.t_pad))];
        let (slots, lens) = (sh.slots(), sh.slot_lengths());
        for (s, main) in want {
            assert_eq!(slots[s], (main, 2, deg), "{}: slot {s} schedule", sh.name);
            assert_eq!(lens[s], (main + 2) * deg + 2, "{}: slot {s} mask length", sh.name);
        }
        let (lo, hi) = Shape::degree_range();
        assert!((lo..=hi).contains(&deg), "{}: the bilinear degree is outside the hash-length table's range", sh.name);
        for l in lens {
            assert!(l + 256 <= 512, "{}: a mask row leaves the M budget", sh.name);
        }
        eprintln!("S20-REVIEW L_s at {}: SC_SCORE {} / SC_PV {} (max over slots {})", sh.name, lens[SC_SCORE], lens[SC_PV], lens.iter().max().unwrap());
    }
}

// ---------------------------------------------------------------- completeness

fn review_ctx() -> Digest {
    *blake3::hash(b"private block: stage 20 independent review, completeness battery").as_bytes()
}

fn run_case(sh: &Shape, blk: &BlockPublic, w: Witness) -> Result<(), String> {
    let ids = Ids::new(sh).expect("plane map");
    let plane = |p: usize| -> Result<Vec<i16>, String> { w.planes[p].iter().map(|v| i16::try_from(*v).map_err(|_| "endpoint word outside int16".to_string())).collect() };
    let (pin, pout) = (plane(ids.at(A_X))?, plane(ids.at(A_X2))?);
    let spec = IoSpec::new_shaped(sh, review_ctx(), 0, 0)?;
    let (expected, owners) = prepare_endpoints(spec, &pin, &pout)?;
    let (receipt, _) = prove_inner_at(sh, blk, w, &expected, owners)?;
    verify_inner_at(sh, blk, &expected, &receipt).map(|_| ())
}

/// **NO HONEST CASE MAY BE REJECTED BY THE VERIFIER.** The completeness
/// statement S19-F1 broke, on cases chosen to stress the head axis: several
/// dense seeds, one key-value group driven to zero while the other is not, a
/// single query head moved, the all-zero hidden input and the old tame
/// fixture. A refusal by the WITNESS BUILDER or by the PROVER is an
/// admissibility statement about a recipe and is recorded, not failed; a
/// VERIFIER rejecting an honest receipt is the S19-F1 class and fails.
#[test]
fn no_honest_case_is_rejected_by_the_verifier_at_the_rung_g() {
    let sh = Shape::rung_g();
    let d = sh.width;
    let mut cases: Vec<(String, Vec<i16>, bool)> = Vec::new();
    // three dense seeds, on the dense STATEMENT (dense Wq/Wk/Wv/Wo), varying
    // only the hidden input, so every key-value head sees different data
    for (k, seed) in [11u64, 2_024, 987_654].into_iter().enumerate() {
        let mut r = Rng(seed);
        let x: Vec<i16> = (0..sh.tokens * d).map(|_| ((r.next() % 12_001) as i64 - 6_000) as i16).collect();
        cases.push((format!("dense statement, random hidden input seed {k}"), x, true));
    }
    // one key-value GROUP zero and the other not: tokens in the first half of
    // the width carry signal, the rest are zero
    {
        let x: Vec<i16> = (0..sh.tokens * d).map(|i| if i % d < d / 2 { 1_500 } else { 0 }).collect();
        cases.push(("half the width zero (one group's activations differ sharply)".into(), x, true));
    }
    // ONE query head's slice of ONE token moved off the fixture
    {
        let (_, _, mut x) = super::grow_tests::tame_case(&sh);
        x[sh.head_dim + 3] = x[sh.head_dim + 3].wrapping_add(97);
        cases.push(("the tame fixture with one query head's word moved".into(), x, false));
    }
    cases.push(("the ALL-ZERO hidden input".into(), vec![0i16; sh.tokens * d], false));
    {
        let (_, _, x) = super::grow_tests::tame_case(&sh);
        cases.push(("the tame fixture itself".into(), x, false));
    }
    let mut rejected: Vec<String> = Vec::new();
    let mut proved = 0usize;
    let mut refused = 0usize;
    for (what, input, dense) in cases {
        let (public, ff) = if dense {
            let (w, _) = super::dense_tests::dense_words_with(&sh, 24, 24, 2, (40, 127), 6_000);
            super::dense_tests::statement_of_words(&sh, &w)
        } else {
            let (p, f, _) = super::grow_tests::tame_case(&sh);
            (p, f)
        };
        let blk = BlockPublic::new(public.clone(), ff.clone());
        match witness::build_shaped(&sh, &public, &ff, &input) {
            Err(e) => {
                eprintln!("HONEST {what}: witness builder refused: {e}");
                refused += 1;
            }
            Ok(w) => match run_case(&sh, &blk, w) {
                Ok(()) => {
                    eprintln!("HONEST {what}: VERIFIED");
                    proved += 1;
                }
                Err(e) => {
                    // a prover-side range refusal is admissibility, not S19-F1
                    if e.contains("range refusal") || e.contains("outside int16") || e.contains("admissib") {
                        eprintln!("HONEST {what}: prover refused (admissibility): {e}");
                        refused += 1;
                    } else {
                        eprintln!("HONEST {what}: REJECTED: {e}");
                        rejected.push(format!("{what}: {e}"));
                    }
                }
            },
        }
    }
    eprintln!("S20-REVIEW completeness battery at the rung-G: {proved} verified, {refused} inadmissible, {} rejected", rejected.len());
    assert!(rejected.is_empty(), "an HONEST case was rejected: {rejected:#?}");
    assert!(proved >= 4, "too few honest cases actually proved ({proved}) for this battery to say anything");
}

// ---------------------------------------------------------------- cheating witnesses

/// **THE PADDED HEAD SLOT IS NOT A FREE PARKING SPACE.** `r_hj` is a random
/// field point, so the two bilinear identities are enforced on the PADDED head
/// slots `{3, 7}` as well as the true ones. Mass put there — in the query
/// factor `A_QR8`, in the probability factor `A_P`, or in the score / output
/// planes the hosts read — must be rejected. And a key of one key-value group
/// serving the other group's heads must be rejected: that is the exact
/// substitution the pre-stage-20 construction could not distinguish.
#[test]
fn mass_in_a_padded_head_slot_or_across_a_key_value_group_is_rejected() {
    let sh = Shape::rung_g();
    // the FULLY dense case: the two key-value groups must genuinely carry
    // different keys and values, or the cross-group substitution below is a
    // no-op and says nothing (measured: on the tame-attention fixture the two
    // groups' rotated keys are identical, so the "swap" changed no word and
    // the receipt was correctly accepted)
    let (public, ff, input) = super::dense_tests::dense_case(&sh);
    let base = witness::build_shaped(&sh, &public, &ff, &input).expect("the honest witness");
    let blk = BlockPublic::new(public, ff);
    let ids = Ids::new(&sh).expect("plane map");
    let (tp, hp, dh, kvw) = (sh.t_pad, sh.h_pad, sh.head_dim, sh.kv_heads * sh.head_dim);
    // the padded head slots of this shape, by name
    let padded: Vec<usize> = (0..hp).filter(|s| !sh.slot_is_true_head(*s)).collect();
    assert_eq!(padded, vec![3, 7], "the rung-G's padded head slots moved");
    assert!(super::review_tests::outcome(&sh, &blk, super::review_tests::clone_witness(&base)).is_accepted(), "the honest control was not accepted, so nothing below is a statement");
    let pad_slot = padded[0];
    let mut cases: Vec<(String, usize, usize)> = Vec::new();
    // A_QR8 is (t, slot, c): token 2, padded slot, dimension 1
    cases.push(("A_QR8 at a PADDED head slot".into(), ids.at(A_QR8), (2 * hp + pad_slot) * dh + 1));
    // A_P is (slot, t, s): padded slot, token 2, source 1
    cases.push(("A_P at a PADDED head slot".into(), ids.at(A_P), (pad_slot * tp + 2) * tp + 1));
    // A_S8 is (slot, t, j): the score of a padded head slot
    cases.push(("A_S8 at a PADDED head slot".into(), ids.at(A_S8), (pad_slot * tp + 2) * tp + 1));
    // A_O8 is (t, slot, i): the output of a padded head slot
    cases.push(("A_O8 at a PADDED head slot".into(), ids.at(A_O8), (2 * hp + pad_slot) * dh + 1));
    // the key of key-value group 1 made to serve group 0's heads: copy group
    // 0's rotated key words over group 1's, which the old construction's
    // shared fixed coordinate could not tell apart from the truth
    let mut swapped = super::review_tests::clone_witness(&base);
    let mut moved = 0usize;
    {
        let p = ids.at(A_KR8);
        for j in 0..tp {
            for c in 0..dh {
                let (from, to) = (j * kvw + c, j * kvw + dh + c);
                if swapped.planes[p][to] != swapped.planes[p][from] {
                    moved += 1;
                }
                swapped.planes[p][to] = swapped.planes[p][from];
            }
        }
    }
    assert!(moved > 0, "the two key-value groups already carry the same keys, so the substitution says nothing");
    let mut accepted: Vec<String> = Vec::new();
    for (what, plane, at) in cases {
        let mut w = super::review_tests::clone_witness(&base);
        w.planes[plane][at] += 1;
        let o = super::review_tests::outcome(&sh, &blk, w);
        eprintln!("CHEAT {what}: {}", o.short());
        if o.is_accepted() {
            accepted.push(what);
        }
    }
    let o = super::review_tests::outcome(&sh, &blk, swapped);
    eprintln!("CHEAT group 0's keys serving group 1: {}", o.short());
    if o.is_accepted() {
        accepted.push("group 0's keys serving group 1".into());
    }
    assert!(accepted.is_empty(), "a cheating witness was ACCEPTED: {accepted:#?}");
}
