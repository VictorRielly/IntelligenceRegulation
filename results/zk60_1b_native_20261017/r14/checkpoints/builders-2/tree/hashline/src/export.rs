//! Reader for the m125 FFN export (results/m125_ffn_export_wsl/):
//! layerNN_X.bin int8 row-major T x d; layerNN_WgT.bin / WuT.bin int8
//! d x f; layerNN_WdT.bin int8 f x d; digests.txt with per layer the
//! lines "NN X|WgT|WuT|WdT|z <sha256>" and "NN shifts g u h z". The
//! interpretation matches zkmatrix-rs's bf_sidecar / bf_load_layer
//! (read-only reference): the sidecar's shifts are the requant shifts
//! g/u/h/z and every tensor digest is sha256 of the raw .bin bytes.

use sha2::{Digest, Sha256};
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

pub const T: usize = 512;
pub const D: usize = 768;
pub const F: usize = 2048;
pub const LAYERS: usize = 12;

/// Exponent rows of results/m125_int8_calibration.json as the export's
/// manifest carries them (eX, eGate, eA, eUp, eH, eZ); eW = -9 uniform.
/// Only used to pick the SiLU family member (eGate, eA); the shifts are
/// read from the sidecar and cross-checked against these.
pub const M125_EXP: [(i32, i32, i32, i32, i32, i32); LAYERS] = [
    (-3, -3, -3, -3, 0, 1),
    (-2, -4, -4, -3, 0, -1),
    (-2, -3, -3, -2, 2, 1),
    (-2, -3, -3, -4, -1, -1),
    (-2, -4, -4, -4, -2, -1),
    (-2, -3, -3, -3, -1, -3),
    (-2, -3, -3, -3, 0, -3),
    (-2, -3, -3, -3, -1, -3),
    (-2, -3, -3, -3, 0, -2),
    (-2, -3, -3, -3, 0, -2),
    (-2, -3, -3, -2, 0, 0),
    (-2, -3, -3, -2, 0, 1),
];
pub const E_W: i32 = -9;

pub fn export_dir() -> PathBuf {
    if let Ok(d) = std::env::var("M125_EXPORT_DIR") {
        return PathBuf::from(d);
    }
    PathBuf::from("/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl")
}

pub struct Sidecar {
    pub map: BTreeMap<(usize, String), String>,
}

impl Sidecar {
    pub fn load(dir: &Path) -> Sidecar {
        let path = dir.join("digests.txt");
        let text = std::fs::read_to_string(&path)
            .unwrap_or_else(|e| panic!("cannot read {} ({e})", path.display()));
        let mut map = BTreeMap::new();
        for line in text.lines() {
            let mut it = line.split_whitespace();
            let l: usize = match it.next() { Some(s) => s.parse().expect("layer no"), None => continue };
            let name = it.next().expect("name").to_string();
            let rest: Vec<&str> = it.collect();
            map.insert((l, name), rest.join(" "));
        }
        Sidecar { map }
    }
    pub fn digest(&self, l: usize, name: &str) -> &str {
        &self.map[&(l, name.to_string())]
    }
    /// (g, u, h, z)
    pub fn shifts(&self, l: usize) -> (u32, u32, u32, u32) {
        let s = &self.map[&(l, "shifts".to_string())];
        let v: Vec<u32> = s.split_whitespace().map(|x| x.parse().unwrap()).collect();
        assert_eq!(v.len(), 4, "layer {l}: bad shifts line");
        (v[0], v[1], v[2], v[3])
    }
}

pub fn sha256_hex(bytes: &[u8]) -> String {
    let mut h = Sha256::new();
    h.update(bytes);
    crate::silu::hex(&h.finalize())
}

/// One layer's raw int8 tensors (as i8, row-major).
pub struct LayerExport {
    pub l: usize,
    pub x: Vec<i8>,    // T x D
    pub wg_t: Vec<i8>, // D x F
    pub wu_t: Vec<i8>, // D x F
    pub wd_t: Vec<i8>, // F x D
    pub shifts: (u32, u32, u32, u32),
    pub e_gate: i32,
    pub e_act: i32,
}

fn read_i8(path: &Path, n: usize) -> Vec<i8> {
    let bytes = std::fs::read(path).unwrap_or_else(|e| panic!("cannot read {} ({e})", path.display()));
    assert_eq!(bytes.len(), n, "{}: wrong size", path.display());
    bytes.into_iter().map(|b| b as i8).collect()
}

fn as_bytes(v: &[i8]) -> &[u8] {
    // SAFETY: i8 and u8 have identical layout.
    unsafe { std::slice::from_raw_parts(v.as_ptr() as *const u8, v.len()) }
}

/// Load layer `l`, checking the four tensor digests against the sidecar
/// and the sidecar's shifts against the calibration exponents (the same
/// derivation as bf_load_layer: sh_g = eGate - eX - eW, sh_u = eUp - eX
/// - eW, sh_h = eH - eA - eUp, sh_z = eZ - eH - eW).
pub fn load_layer(dir: &Path, side: &Sidecar, l: usize) -> LayerExport {
    let x = read_i8(&dir.join(format!("layer{l:02}_X.bin")), T * D);
    let wg_t = read_i8(&dir.join(format!("layer{l:02}_WgT.bin")), D * F);
    let wu_t = read_i8(&dir.join(format!("layer{l:02}_WuT.bin")), D * F);
    let wd_t = read_i8(&dir.join(format!("layer{l:02}_WdT.bin")), F * D);
    for (name, v) in [("X", &x), ("WgT", &wg_t), ("WuT", &wu_t), ("WdT", &wd_t)] {
        let got = sha256_hex(as_bytes(v));
        assert_eq!(got, side.digest(l, name), "layer {l} {name}: export digest mismatch");
    }
    let (e_x, e_gate, e_a, e_up, e_h, e_z) = M125_EXP[l];
    assert_eq!(e_gate, e_a, "family assumes eGate == eA");
    let derived = ((e_gate - e_x - E_W) as u32, (e_up - e_x - E_W) as u32, (e_h - e_a - e_up) as u32, (e_z - e_h - E_W) as u32);
    let shifts = side.shifts(l);
    assert_eq!(shifts, derived, "layer {l}: sidecar shifts disagree with the calibration exponents");
    LayerExport { l, x, wg_t, wu_t, wd_t, shifts, e_gate, e_act: e_a }
}

pub fn i8_digest(v: &[i8]) -> String {
    sha256_hex(as_bytes(v))
}
