//! [ZK60-GZC] The private block's slot 18 (`SC_FZC`, the f-cube zero-check)
//! on the device: the PUBLIC description of its polynomial, the host mirror
//! of the device expression, the switch, and the dispatch. Compiled in every
//! configuration; the CUDA evaluator itself is `cuda.rs`'s `DevFzcRounds`.
//!
//! WHAT MOVES. Only the body of the masked sumcheck — the per-round sums of
//! the slot polynomial over all pairs and the folds — and the construction of
//! its 20/21 tables. The transcript, the CFS masker, every challenge, every
//! random draw, the published scalar, the extension round, the terminals and
//! the claims stay where they are (`argument.rs::run_slot`), and the driver is
//! the unchanged `zk::masked_prove_rounds`: the device evaluator only ever
//! returns UNMASKED round sums through `zkp_core::sumcheck::SumcheckRounds`.
//!
//! WHY THE BYTES ARE THE SAME. The device returns the canonical
//! representatives of the same field elements: the same polynomial (this
//! file's [`FzcDesc::eval`] is the kernel's expression, compared against the
//! slot's own closure by test), the same tables, the same evaluation points,
//! field sums (exact, so their order is irrelevant), the same R1d recovery of
//! `s(1)` as `ClosureRounds::recover_one`.
//!
//! The switch: `HL_GPU_ZEROCHECK=1` (read fresh, off by default). It is
//! honoured only when the GPU path is live; a refusal or a device error goes
//! through `gpu::declined`, which panics under `HL_GPU_REQUIRED=1`.
//! `HL_GZC_CHECK=1` additionally runs the CPU body from the same transcript
//! state and asserts equality (shadow mode). `HL_GZC_PROFILE=1` synchronises
//! after every kernel and prints a per-sumcheck phase/bytes line. Kernel
//! variants (same values): `HL_GZC_SPLIT` (default 1: the term-group split,
//! round 2), `HL_GZC_LEAN` (default 1 among the per-pair kernels),
//! `HL_GZC_FUSED` (default 1), `HL_GZC_TAIL_LOG=t` (rounds over at most 2^t
//! entries on the host; 0 = never).
//!
//! Nothing here touches a transcript, a generator or a committed buffer; the
//! parameters it carries are Fiat-Shamir challenges and shape constants, all
//! public.

use crate::field::{Fp, Fp2};

/// the switch
pub const ENV: &str = "HL_GPU_ZEROCHECK";
/// the shadow-mode switch (run both bodies, assert equality)
pub const CHECK_ENV: &str = "HL_GZC_CHECK";
/// synchronised per-kernel timing and the per-sumcheck report line
pub const PROFILE_ENV: &str = "HL_GZC_PROFILE";

#[cfg(test)]
thread_local! {
    static FORCE: std::cell::Cell<Option<bool>> = const { std::cell::Cell::new(None) };
    static FORCE_CHECK: std::cell::Cell<Option<bool>> = const { std::cell::Cell::new(None) };
}

/// TEST-ONLY: force the switch for THIS THREAD (`None` restores the
/// environment's answer). Same discipline as `private_block::timing::force`.
#[cfg(test)]
pub(crate) fn force(v: Option<bool>) {
    FORCE.with(|c| c.set(v));
}

/// TEST-ONLY: force shadow mode for this thread.
#[cfg(test)]
pub(crate) fn force_check(v: Option<bool>) {
    FORCE_CHECK.with(|c| c.set(v));
}

fn env_on(name: &str) -> bool {
    std::env::var(name).map(|v| v == "1").unwrap_or(false)
}

/// `HL_GPU_ZEROCHECK=1` (read fresh at every slot).
pub fn requested() -> bool {
    #[cfg(test)]
    {
        if let Some(v) = FORCE.with(|c| c.get()) {
            return v;
        }
    }
    env_on(ENV)
}

/// `HL_GZC_CHECK=1`: run the CPU body too and assert equality.
pub fn check_mode() -> bool {
    #[cfg(test)]
    {
        if let Some(v) = FORCE_CHECK.with(|c| c.get()) {
            return v;
        }
    }
    env_on(CHECK_ENV)
}

/// `HL_GZC_PROFILE=1`
pub fn profile() -> bool {
    env_on(PROFILE_ENV)
}

static RUNS: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(0);
static CHECKS: std::sync::atomic::AtomicUsize = std::sync::atomic::AtomicUsize::new(0);

/// device slot-18 sumchecks completed in this process
pub fn runs() -> usize {
    RUNS.load(std::sync::atomic::Ordering::Relaxed)
}
/// shadow-mode equality checks passed in this process
pub fn checks() -> usize {
    CHECKS.load(std::sync::atomic::Ordering::Relaxed)
}
pub(crate) fn note_run() {
    RUNS.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
}
pub(crate) fn note_check() {
    CHECKS.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
}

/// The canonical table layout the kernel is written for. `argument.rs`'s
/// `SC_FZC` arm pushes exactly this order; [`FzcDesc::check_layout`] refuses
/// anything else (a refusal is a decline, never a silent wrong polynomial).
pub const T_EQ: usize = 0; // eq(tau), eq(p_g), eq(p_u): 0, 1, 2
pub const T_A: usize = 3; // the 11 Dom::F A planes, 3 ..= 13
pub const N_A_F: usize = 11;
pub const T_H: usize = 14; // the 5 U8 helpers, 14 ..= 18
pub const N_HELP: usize = 5;
pub const T_FACT: usize = 19;
pub const T_SUPP: usize = 20;
/// the named A planes, as positions inside the A block
pub const A_G8: usize = 0;
pub const A_RGL: usize = 1;
pub const A_A16: usize = 2;
pub const A_U16: usize = 3;
pub const A_UL0: usize = 4;
pub const A_UL1: usize = 5;
pub const A_H16: usize = 6;
pub const A_HL0: usize = 7;
pub const A_HL1: usize = 8;
pub const A_RH0: usize = 9;
pub const A_RH1: usize = 10;
/// the A position each of the nine U8 lookups reads, in helper order
/// (`layout.rs::lookups_at`, `Dom::F`)
pub const LK_PLANES: [usize; 9] = [A_RGL, A_RGL, A_UL0, A_UL1, A_HL0, A_HL1, A_RH0, A_RH1, A_RH1];

/// The PUBLIC parameters of `SC_FZC`'s polynomial, captured in
/// `argument.rs` from the SAME variables the CPU closure captures.
#[derive(Clone, Debug)]
pub struct FzcDesc {
    pub alpha: Fp2,
    pub beta: Fp2,
    pub g_act: Fp2,
    pub nu: [Fp2; 2],
    /// `mu[0..3]` the gated f0/f1/f2, `mu[3]` the activation pair, `mu[4..9]`
    /// the five helpers, `mu[9]` the pad term (only with the pad rule)
    pub mu: Vec<Fp2>,
    /// the nine U8 lookups: constant (tag folded in), coefficient, table index
    pub lk_cst: Vec<Fp2>,
    pub lk_coef: Vec<Fp>,
    pub lk_tab: Vec<usize>,
    /// the closure's table index of each named A plane (`idx[A_*]`), in A order
    pub a_tab: Vec<usize>,
    /// first helper table, helper count, activation helper table
    pub h0: usize,
    pub n_help: usize,
    pub i_fact: usize,
    /// the support indicator's table (the gate), if the profile pads Dom::F
    pub supp: Option<usize>,
    /// the pad term: (table index, zeta power) of each ZERO-rule plane, and mu_pad
    pub pad: Vec<(usize, Fp2)>,
    pub mu_pad: Fp2,
    /// `2^sh_h`, `half(sh_h)`, `2^sh_g`, `half(sh_g)`, `256`, as the closure's Fp2 constants
    pub k_h: Fp2,
    pub k_h_half: Fp2,
    pub k_g: Fp2,
    pub k_g_half: Fp2,
    pub p1: Fp2,
}

/// the parameter block the kernel reads (u64 words; `kernels.cu` FZ_*)
pub const FZ_ALPHA: usize = 0;
pub const FZ_BETA: usize = 2;
pub const FZ_GACT: usize = 4;
pub const FZ_NU0: usize = 6;
pub const FZ_NU1: usize = 8;
pub const FZ_MU: usize = 10; // mu[0..9): 18 words
pub const FZ_MUPAD: usize = 28;
pub const FZ_LKC: usize = 30; // 9 f2
pub const FZ_LKK: usize = 48; // 9 base
pub const FZ_KH: usize = 57;
pub const FZ_KHH: usize = 58;
pub const FZ_KG: usize = 59;
pub const FZ_KGH: usize = 60;
pub const FZ_P1: usize = 61;
pub const FZ_PADW: usize = 62; // 11 f2 (zero for planes outside the pad group)
pub const FZ_LEN: usize = 84;

fn base_of(x: Fp2, what: &str) -> Result<u64, String> {
    if !x.c1.is_zero() {
        return Err(format!("fzc: the constant {what} is not base-field"));
    }
    Ok(x.c0.0)
}

impl FzcDesc {
    /// The table count the kernel expects.
    pub fn k(&self) -> usize {
        if self.supp.is_some() {
            T_SUPP + 1
        } else {
            T_SUPP
        }
    }

    /// The canonical layout, checked: anything else is refused (declined).
    pub fn check_layout(&self, n_tables: usize) -> Result<(), String> {
        if n_tables != self.k() {
            return Err(format!("fzc: {n_tables} tables, the kernel's layout has {}", self.k()));
        }
        if self.a_tab.len() != N_A_F || self.a_tab.iter().enumerate().any(|(j, t)| *t != T_A + j) {
            return Err("fzc: the A planes are not tables 3..=13 in plane order".into());
        }
        if self.h0 != T_H || self.n_help != N_HELP || self.i_fact != T_FACT {
            return Err(format!("fzc: helpers at {} x {} and the activation helper at {}, the kernel's layout is {T_H} x {N_HELP} and {T_FACT}", self.h0, self.n_help, self.i_fact));
        }
        if let Some(s) = self.supp {
            if s != T_SUPP {
                return Err(format!("fzc: the support indicator is table {s}, the kernel's layout has {T_SUPP}"));
            }
        }
        if self.lk_tab.len() != LK_PLANES.len() || self.lk_cst.len() != LK_PLANES.len() || self.lk_coef.len() != LK_PLANES.len() {
            return Err(format!("fzc: {} lookups, the kernel's layout has {}", self.lk_tab.len(), LK_PLANES.len()));
        }
        if self.lk_tab.iter().zip(LK_PLANES.iter()).any(|(t, p)| *t != T_A + p) {
            return Err("fzc: the lookups do not read the kernel's planes".into());
        }
        let want_mu = 4 + N_HELP + usize::from(!self.pad.is_empty());
        if self.mu.len() != want_mu {
            return Err(format!("fzc: {} mu entries, want {want_mu}", self.mu.len()));
        }
        if !self.pad.is_empty() && self.supp.is_none() {
            return Err("fzc: a pad term without a support indicator".into());
        }
        let mut seen = [false; N_A_F];
        for (t, _) in &self.pad {
            if *t < T_A || *t >= T_A + N_A_F || seen[*t - T_A] {
                return Err(format!("fzc: pad plane at table {t} is not a distinct A plane"));
            }
            seen[*t - T_A] = true;
        }
        Ok(())
    }

    /// The kernel's parameter block.
    pub fn params(&self) -> Result<Vec<u64>, String> {
        let mut p = vec![0u64; FZ_LEN];
        let put = |p: &mut Vec<u64>, at: usize, x: Fp2| {
            p[at] = x.c0.0;
            p[at + 1] = x.c1.0;
        };
        put(&mut p, FZ_ALPHA, self.alpha);
        put(&mut p, FZ_BETA, self.beta);
        put(&mut p, FZ_GACT, self.g_act);
        put(&mut p, FZ_NU0, self.nu[0]);
        put(&mut p, FZ_NU1, self.nu[1]);
        for m in 0..4 + N_HELP {
            put(&mut p, FZ_MU + 2 * m, self.mu[m]);
        }
        put(&mut p, FZ_MUPAD, if self.pad.is_empty() { Fp2::ZERO } else { self.mu_pad });
        for k in 0..LK_PLANES.len() {
            put(&mut p, FZ_LKC + 2 * k, self.lk_cst[k]);
            p[FZ_LKK + k] = self.lk_coef[k].0;
        }
        p[FZ_KH] = base_of(self.k_h, "2^sh_h")?;
        p[FZ_KHH] = base_of(self.k_h_half, "half(sh_h)")?;
        p[FZ_KG] = base_of(self.k_g, "2^sh_g")?;
        p[FZ_KGH] = base_of(self.k_g_half, "half(sh_g)")?;
        p[FZ_P1] = base_of(self.p1, "256")?;
        for (t, w) in &self.pad {
            put(&mut p, FZ_PADW + 2 * (*t - T_A), *w);
        }
        Ok(p)
    }

    /// THE KERNEL'S EXPRESSION ON THE HOST, term for term as `kernels.cu`'s
    /// `fzc_poly` writes it (canonical layout; call [`check_layout`] first).
    /// The tests compare this against the slot's own closure, and the device
    /// rounds against `ClosureRounds` on that closure.
    pub fn eval(&self, v: &[Fp2]) -> Fp2 {
        let a = |j: usize| v[T_A + j];
        let base = |c: Fp2| c; // the Fp2 constants with c1 = 0
        let den = |k: usize| self.alpha.sub(self.lk_cst[k].add(a(LK_PLANES[k]).mul_base(self.lk_coef[k])));
        // an array, not a Vec: the host tail (K4) calls this per point
        let d: [Fp2; 9] = std::array::from_fn(den);
        let mu = &self.mu;
        let mut helper = Fp2::ZERO;
        for k in 0..4 {
            let (d1, d2) = (d[2 * k], d[2 * k + 1]);
            helper = helper.add(mu[4 + k].mul(v[T_H + k].mul(d1).mul(d2).sub(d1).sub(d2)));
        }
        helper = helper.add(mu[8].mul(v[T_H + 4].mul(d[8]).sub(Fp2::ONE)));
        let l2 = |o: usize| a(o).add(a(o + 1).mul(self.p1));
        let f0 = a(A_A16).mul(a(A_U16)).sub(a(A_H16).mul(base(self.k_h))).sub(l2(A_RH0)).add(self.k_h_half);
        let f1 = a(A_U16).add(Fp2::from_i64(32768)).sub(l2(A_UL0));
        let f2 = a(A_H16).add(Fp2::from_i64(32768)).sub(l2(A_HL0));
        let fact = v[T_FACT].mul(self.alpha.sub(a(A_G8).add(Fp2::from_i64(128)).add(self.beta.mul(a(A_A16))).add(self.g_act))).sub(Fp2::ONE);
        let gated = mu[0].mul(f0).add(mu[1].mul(f1)).add(mu[2].mul(f2));
        let host_g = self.k_g.mul(a(A_G8)).add(a(A_RGL)).sub(self.k_g_half);
        let host = self.nu[0].mul(v[1]).mul(host_g).add(self.nu[1].mul(v[2]).mul(a(A_U16)));
        let mut zc = helper.add(mu[3].mul(fact));
        match self.supp {
            Some(si) => {
                let s = v[si];
                if !self.pad.is_empty() {
                    let mut lin = Fp2::ZERO;
                    for (t, w) in &self.pad {
                        lin = lin.add(w.mul(v[*t]));
                    }
                    zc = zc.add(self.mu_pad.mul(Fp2::ONE.sub(s)).mul(lin));
                }
                zc = zc.add(s.mul(gated));
                v[0].mul(zc).add(s.mul(host))
            }
            None => {
                zc = zc.add(gated);
                v[0].mul(zc).add(host)
            }
        }
    }
}

/// Where one table of the slot comes from.
pub enum FzcSrc<'a> {
    /// a base-field plane `data[off .. off + 2^n]` of a committed matrix
    /// (the device-resident copy when there is one, else the host words)
    Base { dev: Option<&'a crate::gpu::DevStore>, host: &'a [Fp], off: usize },
    /// an `(re, im)` helper pair of slices
    Pair { dev: Option<&'a crate::gpu::DevStore>, host: &'a [Fp], re: usize, im: usize },
    /// `eq(point, x[start ..])` over the cube
    Eq { point: &'a [Fp2], start: usize },
    /// a host table (a public payload, or an already built table), uploaded
    Host(&'a [Fp2]),
    /// [round 2, K2] a PUBLIC table that is a pure function of `key` (the
    /// caller hashes the full shape, the slot, the table index and the cube
    /// size into it): kept resident on the device per process and copied
    /// device-to-device on later uses; uploaded again whenever a sample of
    /// its entries differs from the cached copy's
    Public { v: &'a [Fp2], key: [u8; 32] },
}

/// (masked rounds, challenges, finals) — `zk::masked_prove_rounds`'s output
pub type MaskedOut = (Vec<Vec<Fp2>>, Vec<Fp2>, Vec<Fp2>);

/// Run slot 18's masked sumcheck on the device. `Err` means the device path
/// did not complete; the caller's transcript is then untouched (the attempt
/// runs on a clone that replaces `tr` only on success).
#[allow(clippy::too_many_arguments)]
pub fn prove(
    desc: &FzcDesc,
    srcs: &[FzcSrc],
    n: usize,
    degree: usize,
    claim: Option<Fp2>,
    mask: &crate::sumcheck::CfsMask,
    c: Fp2,
    tr: &mut crate::transcript::Transcript,
) -> Result<MaskedOut, String> {
    #[cfg(feature = "gpu-cuda")]
    {
        if !crate::gpu::enabled() {
            return Err(format!("the GPU path is not live ({})", crate::gpu::label()));
        }
        desc.check_layout(srcs.len())?;
        if degree != 4 && degree != 5 {
            return Err(format!("fzc: degree {degree} (the kernel has 4 and 5)"));
        }
        let prm = desc.params()?;
        let mut ev = super::cuda::DevFzcRounds::new(srcs, n, degree, &prm, desc.supp.is_some(), claim, desc)?;
        let mut tr2 = crate::transcript::Transcript::clone_state(tr);
        let out = crate::zk::masked_prove_rounds(&mut ev, mask, c, &mut tr2);
        if let Some(e) = ev.error() {
            return Err(e);
        }
        ev.report();
        *tr = tr2;
        note_run();
        Ok(out)
    }
    #[cfg(not(feature = "gpu-cuda"))]
    {
        let _ = (desc, srcs, n, degree, claim, mask, c, tr);
        Err("built without --features gpu-cuda".to_string())
    }
}
