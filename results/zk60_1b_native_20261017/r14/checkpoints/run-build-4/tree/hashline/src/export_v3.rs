//! [UPERF3-ZB] Reader for the m8b v3 export layout + the exact widened
//! chain. The layout is the DOC OF RECORD in scripts/m8b_export_ffn.py
//! ("V3 PROFILE"; writer scripts/m8b_margins.py `v3_witness_walk` /
//! `write_v3_sidecar`), the same one the engine's `uperf-v3 verify-export`
//! reads (zkmatrix-rs/src/bin/ring_matmul.rs, read-only reference):
//!
//!   digests.txt   `00 model <tag>`, `00 dims T d f layers`,
//!                 `00 profile v3-widened`, `00 requant round`,
//!                 optional `00 zpolicy clamp` + `NN zclamps <n>`,
//!                 per layer `NN X|WgT|WuT|WdT|a16|u16|h16|z16 <sha256>`
//!                 (sha256 of the raw .bin bytes), `NN shifts g u h z`
//!                 (SIGNED; negative = exact public up-scaling),
//!                 `NN exps eX eGate eA eUp eH eZ eWg eWu eWd` (base
//!                 exponents; the int16 sites live at base - 8),
//!                 `NN wexps eA16 eU16 eH16 eZ16`, `NN margins ...`,
//!                 `NN table <function> <e_in> <e_out> <digest>`.
//!   layerNN_X.bin   int8  T x d       layerNN_WgT.bin / WuT.bin  int8  d x f
//!   layerNN_WdT.bin int8  f x d       layerNN_{a16,u16,h16}.bin  int16 LE T x f
//!   layerNN_z16.bin int16 LE T x d    (all row-major)
//!
//! THE CHAIN (per layer, exact integers; scripts/m8b_margins.py
//! `make_v3_ffn` with mode "round" = the engine's `u3_derive_chain`):
//!   gacc = X . WgT, uacc = X . WuT                       (int8 x int8, exact)
//!   g8  = rq(gacc, sh_g)   in [-128, 127]  (the table domain; the Python
//!                          honest-witness assert is the tighter +-127)
//!   u16 = rq(uacc, sh_u)   in the int16 class
//!   a16 = S[g8 + 128]      (the frozen int16-out member of (eGate, eA-8))
//!   hh  = a16 * u16        (|hh| < 2^30)
//!   h16 = rq(hh, sh_h)     in the int16 class
//!   dacc = h16 . WdT       (|dacc| <= f * 32767 * 127 < 2^36: i64)
//!   z16 = rq(dacc, sh_z)   in the int16 class
//!   rq(v, s) = floor((v + 2^(s-1)) / 2^s) for s > 0 (ROUND-to-nearest,
//!              half up); v for s = 0; v * 2^-s (exact) for s < 0.
//!   sh_g = eGate - eX - eWg; sh_u = eU16 - eX - eWu; sh_h = eH16 - eA16 -
//!   eU16; sh_z = eZ16 - eH16 - eWd (eA16 = eA - 8 etc., margin-adjusted).
//!
//! THE REMAINDER FORM THE PROOF USES: round-to-nearest at s > 0 is the
//! identity  v = 2^s y + r  with the BALANCED remainder r in [-2^(s-1),
//! 2^(s-1))  — equivalent to the engine's floor relation on the
//! pre-shifted operand (v + 2^(s-1) = 2^s y + r', r' in [0, 2^s), r =
//! r' - 2^(s-1)), so the requant identities stay LINEAR with no constant
//! term and the range fact is a shifted window. At s <= 0 the remainder
//! is identically zero (its "window" is {0}). The witness planes below
//! carry that balanced remainder.
//!
//! THE INT16 CLASS proven is [-32768, 32767] (2^16 rows) — the class the
//! engine's v3 statement proves (its rng-u16/rng-z16 tables are 2^16 rows
//! at offset 32768; its h16 limb split admits -32768); the Python
//! export's honest-witness assert is the tighter +-32767, a subset.

use crate::tables_v3::{int16out_member, Act16Fn};
use crate::phase_profile::{measure, span};
use rayon::prelude::*;
use sha2::{Digest, Sha256};
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct V3Dims {
    pub t: usize,
    pub d: usize,
    pub f: usize,
    pub layers: usize,
}

/// The margin-adjusted exponent set of one layer (the `exps` / `wexps` rows).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct V3Exps {
    pub e_x: i32,
    pub e_g: i32,
    pub e_a16: i32,
    pub e_u16: i32,
    pub e_h16: i32,
    pub e_z16: i32,
    pub e_wg: i32,
    pub e_wu: i32,
    pub e_wd: i32,
}

impl V3Exps {
    /// The SIGNED requant shifts (g, u, h, z).
    pub fn shifts(&self) -> (i32, i32, i32, i32) {
        (self.e_g - self.e_x - self.e_wg, self.e_u16 - self.e_x - self.e_wu, self.e_h16 - self.e_a16 - self.e_u16, self.e_z16 - self.e_h16 - self.e_wd)
    }
}

pub fn export_dir_v3(cli: Option<&str>) -> PathBuf {
    if let Some(d) = cli {
        return PathBuf::from(d);
    }
    if let Ok(d) = std::env::var("HL_EXPORT_DIR") {
        return PathBuf::from(d);
    }
    PathBuf::from("results/m8b_test/m125_v3_export")
}

pub struct V3Sidecar {
    pub map: BTreeMap<(usize, String), String>,
    pub model: String,
    pub dims: V3Dims,
    pub zpolicy: Option<String>,
}

impl V3Sidecar {
    pub fn load(dir: &Path) -> V3Sidecar {
        let path = dir.join("digests.txt");
        let text = std::fs::read_to_string(&path).unwrap_or_else(|e| panic!("cannot read {} ({e})", path.display()));
        let mut map = BTreeMap::new();
        for line in text.lines() {
            let mut it = line.split_whitespace();
            let l: usize = match it.next() {
                Some(s) => s.parse().expect("layer no"),
                None => continue,
            };
            let name = it.next().expect("name").to_string();
            let rest: Vec<&str> = it.collect();
            map.insert((l, name), rest.join(" "));
        }
        let get = |k: &str| map.get(&(0usize, k.to_string())).cloned();
        let profile = get("profile").unwrap_or_else(|| panic!("{}: no `00 profile` row — not a v3 export", path.display()));
        assert_eq!(profile, "v3-widened", "{}: profile row `{profile}` (want v3-widened)", path.display());
        let requant = get("requant").unwrap_or_else(|| panic!("{}: no `00 requant` row", path.display()));
        assert_eq!(requant, "round", "{}: requant row `{requant}` (want round)", path.display());
        let dims: Vec<usize> = get("dims").expect("`00 dims` row").split_whitespace().map(|x| x.parse().unwrap()).collect();
        assert_eq!(dims.len(), 4, "bad dims row");
        let dims = V3Dims { t: dims[0], d: dims[1], f: dims[2], layers: dims[3] };
        let zpolicy = get("zpolicy");
        if let Some(zp) = &zpolicy {
            assert_eq!(zp, "clamp", "zpolicy row: {zp}");
        }
        let model = get("model").unwrap_or_default();
        V3Sidecar { map, model, dims, zpolicy }
    }
    pub fn digest(&self, l: usize, name: &str) -> &str {
        &self.map[&(l, name.to_string())]
    }
    fn ints(&self, l: usize, name: &str, n: usize) -> Vec<i32> {
        let s = &self.map[&(l, name.to_string())];
        let v: Vec<i32> = s.split_whitespace().map(|x| x.parse().unwrap()).collect();
        assert_eq!(v.len(), n, "layer {l}: bad `{name}` row");
        v
    }
    /// The sidecar's SIGNED shifts row (g, u, h, z).
    pub fn shifts(&self, l: usize) -> (i32, i32, i32, i32) {
        let v = self.ints(l, "shifts", 4);
        (v[0], v[1], v[2], v[3])
    }
    /// The base-exponent row (int16 sites at base - 8) + the weight exponents.
    pub fn exps(&self, l: usize) -> V3Exps {
        let e = self.ints(l, "exps", 9);
        let w = self.ints(l, "wexps", 4);
        let x = V3Exps { e_x: e[0], e_g: e[1], e_a16: e[2] - 8, e_u16: e[3] - 8, e_h16: e[4] - 8, e_z16: e[5] - 8, e_wg: e[6], e_wu: e[7], e_wd: e[8] };
        assert_eq!((x.e_a16, x.e_u16, x.e_h16, x.e_z16), (w[0], w[1], w[2], w[3]), "layer {l}: wexps row disagrees with exps - 8");
        x
    }
    /// (function, e_in, e_out, digest)
    pub fn table(&self, l: usize) -> (String, i32, i32, String) {
        let s = &self.map[&(l, "table".to_string())];
        let v: Vec<&str> = s.split_whitespace().collect();
        assert_eq!(v.len(), 4, "layer {l}: bad table row");
        (v[0].to_string(), v[1].parse().unwrap(), v[2].parse().unwrap(), v[3].to_string())
    }
    pub fn zclamps(&self, l: usize) -> Option<u64> {
        self.map.get(&(l, "zclamps".to_string())).map(|s| s.parse().unwrap())
    }
}

pub fn sha256_hex(bytes: &[u8]) -> String {
    let _scope = span("hash.sha256");
    let mut h = Sha256::new();
    h.update(bytes);
    crate::silu::hex(&h.finalize())
}

fn i8_bytes(v: &[i8]) -> &[u8] {
    // SAFETY: i8 and u8 have identical layout.
    unsafe { std::slice::from_raw_parts(v.as_ptr() as *const u8, v.len()) }
}

/// sha256 of an int16-LE serialization of the values (the sidecar's plane
/// convention; values outside i16 wrap — an honest witness has none).
pub fn i16_digest_of_i32(v: &[i32]) -> String {
    let _scope = span("copy.digest_encoding");
    let mut bytes = Vec::with_capacity(v.len() * 2);
    for &x in v {
        bytes.extend_from_slice(&(x as i16).to_le_bytes());
    }
    sha256_hex(&bytes)
}

fn read_i8(path: &Path, n: usize) -> Vec<i8> {
    let bytes = measure("read.export_including_buffer_allocation", || std::fs::read(path)).unwrap_or_else(|e| panic!("cannot read {} ({e})", path.display()));
    assert_eq!(bytes.len(), n, "{}: wrong size", path.display());
    measure("copy.decode_export", || bytes.into_iter().map(|b| b as i8).collect())
}

fn read_i16(path: &Path, n: usize) -> (Vec<i16>, String) {
    let bytes = measure("read.export_including_buffer_allocation", || std::fs::read(path)).unwrap_or_else(|e| panic!("cannot read {} ({e})", path.display()));
    assert_eq!(bytes.len(), 2 * n, "{}: wrong size", path.display());
    let d = sha256_hex(&bytes);
    (measure("copy.decode_export", || bytes.chunks_exact(2).map(|c| i16::from_le_bytes([c[0], c[1]])).collect()), d)
}

/// One layer's raw export: the int8 tensors, the int16 witness planes
/// (when `with_planes`), the statement rows, the frozen member.
pub struct V3LayerExport {
    pub l: usize,
    pub dims: V3Dims,
    pub x: Vec<i8>,    // T x d
    pub wg_t: Vec<i8>, // d x f
    pub wu_t: Vec<i8>, // d x f
    pub wd_t: Vec<i8>, // f x d
    pub a16: Vec<i16>, // T x f (empty unless with_planes)
    pub u16: Vec<i16>,
    pub h16: Vec<i16>,
    pub z16: Vec<i16>, // T x d
    pub exps: V3Exps,
    pub shifts: (i32, i32, i32, i32),
    pub act: Act16Fn,
    pub table: [i16; 256],
    pub table_digest: String,
    /// (tensor name, sha256 reproduced?) for every tensor read.
    pub digest_checks: Vec<(&'static str, bool)>,
}

/// Load layer `l`: every tensor's sha256 against the sidecar, the
/// sidecar's shifts against the exponent-derived ones, the table row
/// against the frozen registry (function, member, digest). Digest
/// mismatches are recorded in `digest_checks` (and asserted unless
/// `lenient`); everything structural is asserted.
pub fn load_layer_v3(dir: &Path, side: &V3Sidecar, l: usize, with_planes: bool, lenient: bool) -> V3LayerExport {
    let _scope = span("export_structure_and_checks");
    let dm = side.dims;
    assert!(l < dm.layers, "layer {l} >= {}", dm.layers);
    let mut checks = Vec::new();
    let x = read_i8(&dir.join(format!("layer{l:02}_X.bin")), dm.t * dm.d);
    let wg_t = read_i8(&dir.join(format!("layer{l:02}_WgT.bin")), dm.d * dm.f);
    let wu_t = read_i8(&dir.join(format!("layer{l:02}_WuT.bin")), dm.d * dm.f);
    let wd_t = read_i8(&dir.join(format!("layer{l:02}_WdT.bin")), dm.f * dm.d);
    for (name, v) in [("X", &x), ("WgT", &wg_t), ("WuT", &wu_t), ("WdT", &wd_t)] {
        let ok = sha256_hex(i8_bytes(v)) == side.digest(l, name);
        assert!(ok || lenient, "layer {l} {name}: export digest mismatch");
        checks.push((name, ok));
    }
    let (mut a16, mut u16, mut h16, mut z16) = (Vec::new(), Vec::new(), Vec::new(), Vec::new());
    if with_planes {
        for (name, n, dst) in [("a16", dm.t * dm.f, &mut a16), ("u16", dm.t * dm.f, &mut u16), ("h16", dm.t * dm.f, &mut h16), ("z16", dm.t * dm.d, &mut z16)] {
            let (v, dg) = read_i16(&dir.join(format!("layer{l:02}_{name}.bin")), n);
            let ok = dg == side.digest(l, name);
            assert!(ok || lenient, "layer {l} {name}: export digest mismatch");
            checks.push((name, ok));
            *dst = v;
        }
    }
    let exps = side.exps(l);
    let shifts = exps.shifts();
    assert_eq!(shifts, side.shifts(l), "layer {l}: sidecar shifts disagree with the exponent-derived signed shifts");
    let (sg, su, sh, sz) = shifts;
    assert!((1..=16).contains(&sg) && (-8..=16).contains(&su) && (0..=16).contains(&sh) && (1..=16).contains(&sz), "layer {l}: shifts {shifts:?} outside the v3 bands");
    let (fname, e_in, e_out, tdig) = side.table(l);
    let act = Act16Fn::from_spec_name(&fname).unwrap_or_else(|| panic!("layer {l}: unknown table function `{fname}`"));
    assert_eq!((e_in, e_out), (exps.e_g, exps.e_a16), "layer {l}: table row member != (eGate, eA - 8)");
    let (table, table_digest) = measure("activation.public_table", || int16out_member(act, e_in, e_out)).unwrap_or_else(|| panic!("layer {l}: ({e_in},{e_out}) is not a frozen {fname} member"));
    assert_eq!(table_digest, tdig, "layer {l}: the table row's digest != the frozen member's");
    if let Some(n) = side.zclamps(l) {
        assert_eq!(n, 0, "layer {l}: {n} z-clamped elements in the witness — the clamp-selector relation is not built on this line");
    }
    V3LayerExport { l, dims: dm, x, wg_t, wu_t, wd_t, a16, u16, h16, z16, exps, shifts, act, table, table_digest, digest_checks: checks }
}

// ---------------------------------------------------------------------------
// the exact chain
// ---------------------------------------------------------------------------

/// c[i][j] = sum_k a[i][k] * b_t[k][j] in i64 (a i32 rows x inner, b_t int8 inner x cols).
pub fn matmul_i32_i8_i64(a: &[i32], b_t: &[i8], rows: usize, inner: usize, cols: usize) -> Vec<i64> {
    let mut c = measure("allocation.matmul_output", || vec![0i64; rows * cols]);
    c.par_chunks_mut(cols).enumerate().for_each(|(i, crow)| {
        for k in 0..inner {
            let av = a[i * inner + k] as i64;
            if av == 0 {
                continue;
            }
            let brow = &b_t[k * cols..(k + 1) * cols];
            for (cv, &bv) in crow.iter_mut().zip(brow.iter()) {
                *cv += av * bv as i64;
            }
        }
    });
    c
}

/// The v3 requantization at a SIGNED shift: (y, r) with v = 2^s y + r and
/// r in the BALANCED window [-2^(s-1), 2^(s-1)) for s > 0 (= round-to-
/// nearest, half up); y = v * 2^-s, r = 0 for s <= 0 (exact up-scaling).
pub fn requant_round(acc: &[i64], sh: i32) -> (Vec<i64>, Vec<i64>) {
    if sh <= 0 {
        let scale = 1i64 << (-sh);
        return (acc.par_iter().map(|&a| a * scale).collect(), vec![0i64; acc.len()]);
    }
    let half = 1i64 << (sh - 1);
    let y: Vec<i64> = acc.par_iter().map(|&a| (a + half) >> sh).collect();
    let r: Vec<i64> = acc.par_iter().zip(y.par_iter()).map(|(&a, &yy)| a - (yy << sh)).collect();
    (y, r)
}

#[inline]
pub fn in_i16_class(v: i64) -> bool {
    (-32768..=32767).contains(&v)
}
#[inline]
pub fn in_rem_window(r: i64, sh: i32) -> bool {
    if sh <= 0 {
        r == 0
    } else {
        let half = 1i64 << (sh - 1);
        (-half..half).contains(&r)
    }
}

/// The derived v3 witness of one layer over its first `t_rows` rows
/// (row-major planes, i32; the balanced remainders).
pub struct V3Witness {
    pub l: usize,
    pub dims: V3Dims,
    pub t_rows: usize,
    pub exps: V3Exps,
    pub shifts: (i32, i32, i32, i32),
    pub act: Act16Fn,
    pub table: [i16; 256],
    pub table_digest: String,
    pub x: Vec<i8>,    // T x d (the full export plane)
    pub wg_t: Vec<i8>, // d x f
    pub wu_t: Vec<i8>,
    pub wd_t: Vec<i8>, // f x d
    pub g8: Vec<i32>, // t_rows x f
    pub rg: Vec<i32>,
    pub a16: Vec<i32>,
    pub u16v: Vec<i32>,
    pub ru: Vec<i32>,
    pub h16: Vec<i32>,
    pub rh: Vec<i32>,
    pub z16: Vec<i32>, // t_rows x d
    pub rd: Vec<i32>,
    pub range_ok: bool,
    /// (a16, u16, h16, z16) int16-LE sha256 of the derived planes (meaningful at t_rows == T).
    pub digests: [String; 4],
}

fn to_i32(v: Vec<i64>) -> Vec<i32> {
    let _scope = span("copy.narrow_planes");
    v.into_par_iter().map(|x| x.clamp(i32::MIN as i64, i32::MAX as i64) as i32).collect()
}

/// Derive the chain from X and the weights (the export's planes are NOT
/// consulted — they are compared afterwards by `compare_planes`).
pub fn derive_v3(ex: &V3LayerExport, t_rows: usize) -> V3Witness {
    derive_v3_with_table(ex, t_rows, ex.table, ex.table_digest.clone())
}

pub fn derive_v3_with_table(ex: &V3LayerExport, t_rows: usize, table: [i16; 256], table_digest: String) -> V3Witness {
    let _scope = span("derive_unattributed");
    let dm = ex.dims;
    assert!(t_rows >= 1 && t_rows <= dm.t);
    let (sh_g, sh_u, sh_h, sh_z) = ex.shifts;
    let (d, f) = (dm.d, dm.f);
    let gacc = measure("matmul.gate", || crate::chain::matmul_i8_i32(&ex.x[..t_rows * d], &ex.wg_t, t_rows, d, f));
    let gacc: Vec<i64> = measure("copy.widen_accumulators", || gacc.into_par_iter().map(|v| v as i64).collect());
    let uacc = measure("matmul.up", || crate::chain::matmul_i8_i32(&ex.x[..t_rows * d], &ex.wu_t, t_rows, d, f));
    let uacc: Vec<i64> = measure("copy.widen_accumulators", || uacc.into_par_iter().map(|v| v as i64).collect());
    let (g8, rg) = measure("requant.gate", || requant_round(&gacc, sh_g));
    let (u16v, ru) = measure("requant.up", || requant_round(&uacc, sh_u));
    measure("deallocation.temporary", || { drop(gacc); drop(uacc); });
    let (g_ok, u_ok) = measure("check.ranges", || (g8.iter().all(|&g| (-128..=127).contains(&g)), u16v.iter().all(|&u| in_i16_class(u))));
    let a16: Vec<i64> = measure("activation.lookup", || g8.par_iter().map(|&g| table[((g + 128).clamp(0, 255)) as usize] as i64).collect());
    let hh: Vec<i64> = measure("activation.hadamard", || a16.par_iter().zip(u16v.par_iter()).map(|(&a, &u)| a * u).collect());
    let (h16, rh) = measure("requant.hadamard", || requant_round(&hh, sh_h));
    measure("deallocation.temporary", || drop(hh));
    let h_ok = measure("check.ranges", || h16.iter().all(|&h| in_i16_class(h)));
    let h16_32 = to_i32(h16);
    let dacc = measure("matmul.down", || matmul_i32_i8_i64(&h16_32, &ex.wd_t, t_rows, f, d));
    let (z16, rd) = measure("requant.down", || requant_round(&dacc, sh_z));
    measure("deallocation.temporary", || drop(dacc));
    let z_ok = measure("check.ranges", || z16.iter().all(|&z| in_i16_class(z)));
    let rem_ok = measure("check.ranges", || rg.iter().all(|&r| in_rem_window(r, sh_g))
        && ru.iter().all(|&r| in_rem_window(r, sh_u))
        && rh.iter().all(|&r| in_rem_window(r, sh_h))
        && rd.iter().all(|&r| in_rem_window(r, sh_z)));
    let (g8, rg, a16, u16v, ru, rh, z16, rd) = (to_i32(g8), to_i32(rg), to_i32(a16), to_i32(u16v), to_i32(ru), to_i32(rh), to_i32(z16), to_i32(rd));
    let digests = [i16_digest_of_i32(&a16), i16_digest_of_i32(&u16v), i16_digest_of_i32(&h16_32), i16_digest_of_i32(&z16)];
    measure("copy.clone_witness", || V3Witness {
        l: ex.l,
        dims: dm,
        t_rows,
        exps: ex.exps,
        shifts: ex.shifts,
        act: ex.act,
        table,
        table_digest,
        x: ex.x.clone(),
        wg_t: ex.wg_t.clone(),
        wu_t: ex.wu_t.clone(),
        wd_t: ex.wd_t.clone(),
        g8, rg, a16, u16v, ru,
        h16: h16_32,
        rh, z16, rd,
        range_ok: g_ok && u_ok && h_ok && z_ok && rem_ok,
        digests,
    })
}

/// Element-wise comparison of the derived planes against the export's
/// planes on the first t_rows rows: (name, mismatching elements).
pub fn compare_planes(w: &V3Witness, ex: &V3LayerExport) -> Vec<(&'static str, usize)> {
    let dm = w.dims;
    let cmp = |mine: &[i32], theirs: &[i16], n: usize| -> usize { mine[..n].iter().zip(theirs[..n].iter()).filter(|(&a, &b)| a != b as i32).count() };
    let nf = w.t_rows * dm.f;
    let nd = w.t_rows * dm.d;
    vec![("a16", cmp(&w.a16, &ex.a16, nf)), ("u16", cmp(&w.u16v, &ex.u16, nf)), ("h16", cmp(&w.h16, &ex.h16, nf)), ("z16", cmp(&w.z16, &ex.z16, nd))]
}

pub fn clone_witness_v3(w: &V3Witness) -> V3Witness {
    V3Witness {
        l: w.l, dims: w.dims, t_rows: w.t_rows, exps: w.exps, shifts: w.shifts, act: w.act, table: w.table, table_digest: w.table_digest.clone(),
        x: w.x.clone(), wg_t: w.wg_t.clone(), wu_t: w.wu_t.clone(), wd_t: w.wd_t.clone(),
        g8: w.g8.clone(), rg: w.rg.clone(), a16: w.a16.clone(), u16v: w.u16v.clone(), ru: w.ru.clone(), h16: w.h16.clone(), rh: w.rh.clone(),
        z16: w.z16.clone(), rd: w.rd.clone(), range_ok: w.range_ok, digests: w.digests.clone(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn requant_round_is_the_prescaled_floor() {
        // v = 2^s y + r, r in [-2^(s-1), 2^(s-1)), y == floor((v + 2^(s-1)) / 2^s)
        for &s in &[1i32, 2, 5, 9, 16] {
            let m = 1i64 << s;
            let half = m / 2;
            let acc: Vec<i64> = (-70000..70000).collect();
            let (y, r) = requant_round(&acc, s);
            for (i, &a) in acc.iter().enumerate() {
                assert_eq!(y[i], (a + half).div_euclid(m));
                assert_eq!(a, y[i] * m + r[i]);
                assert!(in_rem_window(r[i], s), "s {s} a {a} r {}", r[i]);
            }
        }
        // s <= 0: exact up-scaling, zero remainder
        let acc: Vec<i64> = vec![-5, 0, 7];
        assert_eq!(requant_round(&acc, 0), (vec![-5, 0, 7], vec![0, 0, 0]));
        assert_eq!(requant_round(&acc, -2), (vec![-20, 0, 28], vec![0, 0, 0]));
        assert!(in_rem_window(0, -1) && !in_rem_window(1, 0));
    }

    #[test]
    fn matmul_i64_small() {
        let a: Vec<i32> = vec![30000, -2, 3, 4, 5, 6]; // 2 x 3
        let b: Vec<i8> = vec![127, 8, 9, 10, 11, 12]; // 3 x 2
        let c = matmul_i32_i8_i64(&a, &b, 2, 3, 2);
        assert_eq!(c, vec![30000 * 127 - 18 + 33, 30000 * 8 - 20 + 36, 508 + 45 + 66, 32 + 50 + 72]);
    }

    #[test]
    fn witness_i64_matmul_scalar_oracle_signed_extremes_and_tails() {
        for &(rows, inner, cols) in &[(0, 3, 5), (1, 0, 7), (1, 1, 1), (3, 7, 5),
                                     (4, 9, 127), (5, 13, 128), (7, 17, 129), (9, 33, 259)] {
            let values = [i32::MIN, i32::MAX, -32768, 32767, -1, 0, 1];
            let weights = [i8::MIN, i8::MAX, -1, 0, 1];
            let a: Vec<i32> = (0..rows * inner).map(|i| values[(i * 3 + 1) % values.len()]).collect();
            let b: Vec<i8> = (0..inner * cols).map(|i| weights[(i * 7 + 2) % weights.len()]).collect();
            let mut expected = vec![0i64; rows * cols];
            for r in 0..rows {
                for j in 0..cols {
                    let mut sum = 0i128;
                    for k in 0..inner { sum += i128::from(a[r * inner + k]) * i128::from(b[k * cols + j]); }
                    expected[r * cols + j] = i64::try_from(sum).unwrap();
                }
            }
            assert_eq!(matmul_i32_i8_i64(&a, &b, rows, inner, cols), expected, "shape {rows}/{inner}/{cols}");
            assert_eq!(matmul_i32_i8_i64(&vec![0; a.len()], &b, rows, inner, cols), vec![0; rows * cols]);
            assert_eq!(matmul_i32_i8_i64(&a, &vec![0; b.len()], rows, inner, cols), vec![0; rows * cols]);
        }
        // Multiplication must widen before the product, not after i32 overflow.
        assert_eq!(matmul_i32_i8_i64(&[i32::MIN], &[i8::MIN], 1, 1, 1), vec![1i64 << 38]);
    }

    #[test]
    #[should_panic]
    fn witness_i64_matmul_zero_columns_still_rejects() {
        matmul_i32_i8_i64(&[], &[], 0, 0, 0);
    }
}
