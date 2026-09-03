//! [UPERF3-AE] The attention half of a transformer layer in the hash-line
//! statement: the exact integer chain (rung 3) and, after it, the prover
//! and verifier of one FULL layer (rung 4: attention + norms + residual
//! stream + the v3 FFN + the seam to the next layer's input).
//!
//! THE STATEMENT (one layer; shapes (T, d, H, H_kv, d_h, f); the design
//! of record docs/zkmatrix-poc/U_PERF3_ATTENTION_STATEMENT_DESIGN.md and
//! ATTENTION_INTEGER_SPEC.md sections 2.1-2.7, instantiated on the
//! hash line's primitives — the full per-tensor table is the ledger's
//! Agent AE rung-0 record):
//!
//!   x_in  (T x d, int16 at e_r; layer 0: the int8 embedding rows at eX0)
//!   attn_norm (norm.rs) ............................. xn8 (int8, e_xn)
//!   Qacc = xn8 . Wq^T, Kacc, Vacc (matmul sumchecks, inner d)
//!   q8/k8/v8 = round-requant (balanced windows), int8 at e_q/e_k/e_v
//!   RoPE (public rope-cs tables at fRo 7, the rotate-half rows):
//!     QRacc = c q_lo - s q_hi | s q_lo + c q_hi ; qr8 = round-requant by 2^7
//!     (scale-preserving; the same on k) — a zero-check reading q8 at the
//!     coordinate-flipped point (PW-1)
//!   Sacc(h, t, j) = sum_i qr8(t, h, i) kr8(j, g(h), i)   (per-head matmul
//!     sumcheck over (h, i); the GQA map g(h) = h / (H / H_kv) is the
//!     kv-head index = the high bits of h: public structure, PW-2)
//!   s8 = round-requant(Sacc, sh_s), int8 at eS_raw = e_q + e_k + sh_s
//!   softmax per (h, t): sM = s8 on the causal support, -127 off it (the
//!     public mask, PW-3); m = row max (committed, H x T); d = m - sM;
//!     zsel binary with row sum 1 and zsel . d = 0 (attainment);
//!     (d, E) in the exp member (eS_raw, d_h, fE) (dominance + the table);
//!     Sum = masked row sum of E (a sumcheck); P Sum + rho = 2^fP E on the
//!     support, P = rho = 0 off it; P in [0, 2^fP]; rho, sigma = Sum - 1 - rho
//!     in [0, 2^wrho), wrho = fE + log2 T
//!   Oacc(t, h, i) = sum_j P(h, t, j) v8(j, g(h), i)  (matmul sumcheck over (h, j))
//!   o8 = round-requant(Oacc, sh_o) int8 at e_o (sh_o = e_o - (e_v - fP))
//!   AOacc = o8 . Wo^T (inner H d_h); ao8 = round-requant, int8 at e_ao
//!   xres1 = round-requant(x_in 2^(e_r - e_c) + ao8 2^(e_ao - e_c), sh_r1), int16 at e_r1
//!   mlp_norm (norm.rs) on xres1 ...................... xm8 (int8, e_xm) = the FFN's X
//!   the v3 FFN (layer.rs, ZB): g8/rg/a16/u16/ru/h16/rh/z16/rd from xm8
//!   xres2 = round-requant(xres1 2^(e_r1 - e_c') + z16 2^(e_z16 - e_c'), sh_r2), int16 at e_r2
//!   THE SEAM: xres2 of layer l IS x_in of layer l + 1 — one MLE equality
//!     at a point drawn after BOTH commitments (layer l's A opening is
//!     deferred until layer l + 1's input is committed).
//!
//! Deferred and stated: the KV cache / decode regime (prefill only), the
//! embedding (X0 committed, its gather not proven), the final norm and
//! the LM head, sliding windows (T <= window: plain causal).
//!
//! Rung 0 (2026-09-03): this module doc + the shape record. Rung 3 fills
//! the chain, rung 4 the prover/verifier.

/// The public shape of one attention layer.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct AttnShape {
    pub t: usize,
    pub d: usize,
    pub heads: usize,
    pub kv_heads: usize,
    pub head_dim: usize,
    pub f: usize,
}

impl AttnShape {
    pub fn m125() -> AttnShape {
        AttnShape { t: 512, d: 768, heads: 12, kv_heads: 4, head_dim: 64, f: 2048 }
    }
    pub fn mistral7b() -> AttnShape {
        AttnShape { t: 512, d: 4096, heads: 32, kv_heads: 8, head_dim: 128, f: 14336 }
    }
    pub fn gqa_group(&self) -> usize {
        assert_eq!(self.heads % self.kv_heads, 0);
        self.heads / self.kv_heads
    }
    /// The kv head of query head h (the high bits of h).
    pub fn kv_of(&self, h: usize) -> usize {
        h / self.gqa_group()
    }
}
