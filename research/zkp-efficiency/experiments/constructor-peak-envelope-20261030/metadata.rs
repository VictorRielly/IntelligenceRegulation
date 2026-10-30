#[derive(Clone,Copy,Debug,PartialEq,Eq)] enum Dom {T,Ht,L,D,Q,Kv,S,F,Tab,Dd}
impl Dom {fn carries_h_planes(self)->bool {!matches!(self,Dom::T|Dom::Ht)}}
const LIMBS_ISQRT:usize=3; const U8_LEN:usize=256; const F_P:u32=9;
fn clog2(v:usize)->usize {assert!(v>0);v.next_power_of_two().trailing_zeros() as usize}
struct Shape {tokens:usize,width:usize,hidden:usize,q_heads:usize,head_dim:usize,kv_heads:usize,
log_cols:usize,dd_cap:usize,t_pad:usize,d_pad:usize,h_pad:usize,f_pad:usize,
norm_wrho:u32,wrho_s:u32,stack:super::accuracy_precision::Stack}
impl Shape {
fn accuracy_stack(&self)->super::accuracy_precision::Stack {self.stack}
fn carries_pad_rule(&self)->bool {true}
    pub(crate) fn f_p(&self) -> u32 {
        if self.accuracy_stack()==super::accuracy_precision::Stack::Legacy {F_P} else {12}
    }
    pub(crate) fn limbs_norm(&self) -> usize {
        if self.accuracy_stack()!=super::accuracy_precision::Stack::Legacy {3} else {self.norm_wrho.div_ceil(8) as usize}
    }
    pub(crate) fn norm_top_is_full_byte(&self) -> bool {
        self.accuracy_stack()!=super::accuracy_precision::Stack::Legacy || self.norm_wrho == 8 * self.limbs_norm() as u32
    }
    pub(crate) fn limbs_sigma_s(&self) -> usize {
        self.wrho_s.div_ceil(8) as usize
    }
    pub(crate) fn limbs_p(&self) -> usize {
        (self.f_p() + 1).div_ceil(8) as usize
    }
    pub(crate) fn q_pad(&self) -> usize {
        self.h_pad * self.head_dim
    }
    pub(crate) fn natural_log(&self, dom: Dom) -> usize {
        match dom {
            Dom::T => clog2(self.t_pad),
            Dom::Ht => clog2(self.h_pad * self.t_pad),
            // sixteen packed limb sub-planes of `T`
            Dom::L => clog2(16 * self.t_pad),
            Dom::D => clog2(self.t_pad * self.d_pad),
            Dom::Q => clog2(self.t_pad * self.h_pad * self.head_dim),
            Dom::Kv => clog2(self.t_pad * self.kv_heads * self.head_dim),
            Dom::S => clog2(self.h_pad * self.t_pad * self.t_pad),
            Dom::F => clog2(self.t_pad * self.f_pad),
            Dom::Tab => clog2(U8_LEN),
            // NATIVE R9 (D30, B-4): the dictionary cube (h, t | k), `dd_cap`
            // slots per (h, t) row; a shape without a dictionary has no such
            // domain (a 1-entry placeholder, never laid out)
            Dom::Dd => clog2(self.h_pad * self.t_pad * self.dd_cap.max(1)),
        }
    }
    pub(crate) fn true_size(&self, dom: Dom) -> usize {
        match dom {
            Dom::T => self.tokens,
            Dom::Ht => self.q_heads * self.tokens,
            Dom::L => 3 * LIMBS_ISQRT * self.tokens,
            Dom::D => self.tokens * self.width,
            Dom::Q => self.tokens * self.q_heads * self.head_dim,
            Dom::Kv => self.tokens * self.kv_heads * self.head_dim,
            Dom::S => self.q_heads * self.tokens * self.tokens,
            Dom::F => self.tokens * self.hidden,
            Dom::Tab => U8_LEN,
            Dom::Dd => self.q_heads * self.tokens * self.dd_cap.max(1),
        }
    }
    pub(crate) fn log(&self, dom: Dom) -> usize {
        domain_log_at(self.natural_log(dom), dom.carries_h_planes(), self.log_cols)
    }
    pub(crate) fn size(&self, dom: Dom) -> usize {
        1usize << self.log(dom)
    }
    pub(crate) fn rows_of(&self, dom: Dom) -> usize {
        std::cmp::max(1, self.size(dom) >> self.log_cols)
    }
    pub(crate) fn pads(&self, dom: Dom) -> bool {
        self.size(dom) != self.true_size(dom)
    }
    pub(crate) fn a_plane_doms(&self) -> Vec<Dom> {
        if self.accuracy_stack()!=super::accuracy_precision::Stack::Legacy {
            let h24=self.accuracy_stack()==super::accuracy_precision::Stack::LowH24;
            let mut v=vec![Dom::T;4];v.extend([Dom::Ht;2]);v.extend([Dom::L;2]);
            v.extend(vec![Dom::D;if h24 {39} else {38}]);v.extend([Dom::Q;14]);v.extend([Dom::Kv;14]);
            v.extend(vec![Dom::S;if self.dd_cap>0 {7} else {9+2*self.limbs_sigma_s()}]);v.extend([Dom::F;16]);
            if self.dd_cap>0 {v.extend(vec![Dom::Dd;4+2*self.limbs_sigma_s()]);}
            v.extend([Dom::Tab;3]);return v;
        }

        let ln = self.limbs_norm();
        let mut v = vec![Dom::T; 4];
        v.extend([Dom::Ht; 2]);
        v.extend([Dom::L; 2]);
        // Dom::D: x, its two limbs, y; norm_a's rho and sigma limbs; the
        // attention output and residual 1 with their limbs; norm_m's rho and
        // sigma limbs; z16, residual 2 and the down-projection remainder
        v.extend(vec![Dom::D; 4 + 2 * ln + 8 + 2 * ln + 7]);
        v.extend([Dom::Q; 7]);
        v.extend([Dom::Kv; 6]);
        if self.dd_cap > 0 {
            // NATIVE R9 (D30): a score entry keeps S8, RSL, ZSEL, E and P and
            // drops its own quotient / remainder limbs; the dictionary carries
            // them, per slot, with the quotient itself and the multiplicity —
            // committed in `A`, before every LogUp challenge (B-2), and BELOW
            // the three histograms (CHECK.md E-1)
            v.extend([Dom::S; 5]);
            v.extend([Dom::F; 11]);
            v.extend(vec![Dom::Dd; 2 + self.limbs_p() + 2 * self.limbs_sigma_s()]);
        } else {
            v.extend(vec![Dom::S; 5 + self.limbs_p() + 2 * self.limbs_sigma_s()]);
            v.extend([Dom::F; 11]);
        }
        v.extend([Dom::Tab; 3]);
        v
    }
    pub(crate) fn lookups_per_position(&self, dom: Dom) -> usize {
        if self.accuracy_stack()!=super::accuracy_precision::Stack::Legacy {
            return match dom {Dom::L=>2,Dom::D=>if self.accuracy_stack()==super::accuracy_precision::Stack::LowH24 {34} else {33},
                Dom::Q|Dom::Kv|Dom::F=>14,Dom::S=>if self.dd_cap>0 {6} else {11+2*self.limbs_sigma_s()},
                Dom::Dd if self.dd_cap>0=>5+2*self.limbs_sigma_s(),_=>0};
        }

        let ln = self.limbs_norm();
        let top = usize::from(!self.norm_top_is_full_byte());
        // sym(y) + rho limbs (+ the scaled top) + sigma limbs (+ the scaled top)
        let per_norm = 2 + 2 * (ln + top);
        match dom {
            Dom::L => 2,
            // the two `x` limbs; norm_a; ao/a-limbs/ral/scaled(ral)/x1 limbs;
            // norm_m; the two `x2` limbs; the down-projection's four
            Dom::D => 2 + per_norm + 6 + per_norm + 2 + 4,
            Dom::F => 9,
            Dom::Q => 13,
            Dom::Kv => 12,
            // sym(s8); rsl + scaled; p limbs + scaled top; rho_s and sigma_s
            // limbs, each with a scaled top. NATIVE R9: on a DD profile the
            // last three groups move to the dictionary (D30)
            Dom::S if self.dd_cap > 0 => 2 + 2,
            Dom::S => 2 + 2 + (self.limbs_p() + 1) + 2 * (self.limbs_sigma_s() + 1),
            // NATIVE R9 (D30, B-1): at EVERY dictionary slot, the quotient's
            // limbs + scaled top and rho_s / sigma_s limbs, each with a scaled
            // top — today's division limbs, verbatim
            Dom::Dd if self.dd_cap > 0 => (self.limbs_p() + 1) + 2 * (self.limbs_sigma_s() + 1),
            Dom::T | Dom::Ht | Dom::Tab | Dom::Dd => 0,
        }
    }
    pub(crate) fn helpers(&self, dom: Dom) -> usize {
        self.lookups_per_position(dom).div_ceil(2)
    }
    pub(crate) fn h_plane_doms(&self) -> Vec<Dom> {
        let mut v = vec![Dom::L; self.helpers(Dom::L)];
        v.extend(vec![Dom::D; self.helpers(Dom::D)]);
        v.extend(vec![Dom::Q; self.helpers(Dom::Q)]);
        v.extend(vec![Dom::Kv; self.helpers(Dom::Kv)]);
        // the `Dom::S` helpers plus the exponential pair's own helper
        // (NATIVE R9: plus, on a DD profile, the score entry's single tuple
        // helper into its row's dictionary)
        v.extend(vec![Dom::S; self.helpers(Dom::S) + 1 + usize::from(self.dd_cap > 0)]);
        // the `Dom::F` helpers plus the activation pair's own helper
        v.extend(vec![Dom::F; self.helpers(Dom::F) + 1]);
        // NATIVE R9 (D30): the dictionary's byte-lookup helpers and its TABLE
        // helper (which enters the value-0 sum claim with sign -1)
        if self.dd_cap > 0 {
            v.extend(vec![Dom::Dd; self.helpers(Dom::Dd) + 1]);
        }
        // the three table helpers and the zero-sum pair `u` (P-3 / P-6: `u`
        // stays the last plane, on `Dom::Tab`)
        v.extend([Dom::Tab; 4]);
        v
    }

    fn a_planes_on(&self, dom: Dom) -> usize {
        self.a_plane_doms().iter().filter(|d| **d == dom).count()
    }
    pub(crate) fn claim_sites(&self) -> ([usize; MAX_SLOTS], [usize; MAX_SLOTS]) {
        let mut a = [0usize; MAX_SLOTS];
        let mut h = [0usize; MAX_SLOTS];
        a[SC_SS] = 1;
        a[SC_SSM] = 1;
        // the four `Dom::T` planes, plus nine limb sub-slices per norm
        a[SC_TZC] = 4 + 2 * (3 * LIMBS_ISQRT);
        a[SC_LZC] = self.a_planes_on(Dom::L);
        h[SC_LZC] = self.helpers(Dom::L);
        a[SC_RS] = 2;
        for s in [SC_QMM, SC_KMM, SC_VMM, SC_WO, SC_GMM, SC_UMM, SC_DMM] {
            a[s] = 1;
        }
        a[SC_SCORE] = 2;
        a[SC_PV] = 2;
        // + the two `Dom::T` denominators
        a[SC_DZC] = self.a_planes_on(Dom::D) + 2;
        h[SC_DZC] = self.helpers(Dom::D);
        // + the flipped RoPE partner
        a[SC_QZC] = self.a_planes_on(Dom::Q) + 1;
        h[SC_QZC] = self.helpers(Dom::Q);
        a[SC_KVZC] = self.a_planes_on(Dom::Kv) + 1;
        h[SC_KVZC] = self.helpers(Dom::Kv);
        // + A_MX and A_SUM; + H_SEXP (NATIVE R9: + the tuple helper on a DD
        // profile, whose `Dom::S` block is five planes)
        a[SC_SZC] = self.a_planes_on(Dom::S) + 2;
        h[SC_SZC] = self.helpers(Dom::S) + 1 + usize::from(self.dd_cap > 0);
        // + H_FACT
        a[SC_FZC] = self.a_planes_on(Dom::F);
        h[SC_FZC] = self.helpers(Dom::F) + 1;
        a[SC_TAB] = 3;
        h[SC_TAB] = 3;
        h[SC_ZS] = 1;
        a[SC_IO_IN] = 1;
        a[SC_IO_OUT] = 1;
        // NATIVE R9 (D30): the dictionary zero-check — every `Dom::Dd` plane
        // on its own cube, plus `A_SUM` read on the leading (h, t) variables
        // (B-4: a claim site of this slot); its byte helpers plus the table
        // helper. Each plane is opened only at its own reserved site.
        if self.dd_cap > 0 {
            a[SC_DD] = self.a_planes_on(Dom::Dd) + 1;
            h[SC_DD] = self.helpers(Dom::Dd) + 1;
        }
        (a, h)
    }
    pub(crate) fn n_slots(&self) -> usize {
        N_SLOTS + usize::from(self.dd_cap > 0)
    }
    pub(crate) fn m_rows(&self) -> usize {
        2 * self.n_slots() + 4
    }
    pub(crate) fn slots(&self) -> [(usize, usize, usize); MAX_SLOTS] {
        let cube = |s: usize| -> Option<Dom> {
            Some(match s {
                SC_DD => Dom::Dd,
                SC_SS | SC_SSM | SC_DZC | SC_IO_IN | SC_IO_OUT => Dom::D,
                SC_TZC => Dom::T,
                SC_LZC => Dom::L,
                SC_RS | SC_SZC => Dom::S,
                SC_QZC => Dom::Q,
                SC_KVZC => Dom::Kv,
                SC_FZC => Dom::F,
                SC_TAB | SC_ZS => Dom::Tab,
                _ => return None,
            })
        };
        // **STAGE 20, the fix of finding S19-F1.** The two BILINEAR slots also
        // sum over the key-value GROUP bits. Those bits are a coordinate of
        // BOTH private factors, and the multilinear extension of a product
        // that shares a variable is not the product of the extensions, so they
        // cannot be fixed on both sides; they are sumcheck variables with a
        // public `eq(r_g, .)` over them. `kv_heads == 1` gives `lkv == 0` and
        // the toy's schedule is untouched, byte for byte.
        let lkv = clog2(self.kv_heads);
        let inner = |s: usize| -> usize {
            match s {
                SC_QMM | SC_KMM | SC_VMM | SC_GMM | SC_UMM => clog2(self.d_pad),
                // NATIVE R12 (F2): `Wo` folds over the QUERY axis
                SC_WO => clog2(self.q_pad()),
                SC_SCORE => lkv + clog2(self.head_dim),
                SC_PV => lkv + clog2(self.t_pad),
                SC_DMM => clog2(self.f_pad),
                _ => unreachable!(),
            }
        };
        let mut out = [(0usize, 0usize, 0usize); MAX_SLOTS];
        for s in 0..self.n_slots() {
            let main = match cube(s) {
                Some(dom) => self.log(dom),
                None => inner(s),
            };
            // the PROFILE gate of finding S9-F1: the frozen toy profile
            // carries no pad machinery, so no toy degree can move
            let indicator = self.carries_pad_rule() && INDICATOR_SLOT_DOMAIN.iter().any(|(slot, dom)| *slot == s && self.pads(*dom));
            // the two bilinear matmuls mask two private factors, in extension
            // rounds 0 and 1; every other slot has one extension round
            let ext = if s == SC_SCORE || s == SC_PV { 2 } else { 1 };
            // STAGE 20: the group `eq` is a THIRD factor of the bilinear
            // slots' monomial, so their degree is 3 — and only when there is
            // more than one key-value head, so the toy keeps its 2 and its
            // transcript.
            let group_eq = (s == SC_SCORE || s == SC_PV) && lkv > 0;
            out[s] = (main, ext, BASE_DEGREE[s] + usize::from(indicator) + usize::from(group_eq));
        }
        out
    }
}
pub(crate) const N_SLOTS: usize = 23;
pub(crate) const SC_SS: usize = 0;
pub(crate) const SC_SSM: usize = 1;
pub(crate) const SC_TZC: usize = 2;
pub(crate) const SC_LZC: usize = 3;
pub(crate) const SC_RS: usize = 4;
pub(crate) const SC_QMM: usize = 5;
pub(crate) const SC_KMM: usize = 6;
pub(crate) const SC_VMM: usize = 7;
pub(crate) const SC_SCORE: usize = 8;
pub(crate) const SC_PV: usize = 9;
pub(crate) const SC_WO: usize = 10;
pub(crate) const SC_GMM: usize = 11;
pub(crate) const SC_UMM: usize = 12;
pub(crate) const SC_DMM: usize = 13;
pub(crate) const SC_DZC: usize = 14;
pub(crate) const SC_QZC: usize = 15;
pub(crate) const SC_KVZC: usize = 16;
pub(crate) const SC_SZC: usize = 17;
pub(crate) const SC_FZC: usize = 18;
pub(crate) const SC_TAB: usize = 19;
pub(crate) const SC_ZS: usize = 20;
pub(crate) const SC_IO_IN: usize = 21;
pub(crate) const SC_IO_OUT: usize = 22;
pub(crate) const SC_DD: usize = 23;
pub(crate) const MAX_SLOTS: usize = 24;
const BASE_DEGREE: [usize; MAX_SLOTS] = [3, 3, 3, 4, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 4, 3, 2, 2, 2, 4];
const INDICATOR_SLOT_DOMAIN: [(usize, Dom); 8] =
    [(SC_SS, Dom::D), (SC_SSM, Dom::D), (SC_RS, Dom::S), (SC_DZC, Dom::D), (SC_QZC, Dom::Q), (SC_KVZC, Dom::Kv), (SC_SZC, Dom::S), (SC_FZC, Dom::F)];
pub(crate) fn domain_log_at(natural: usize, carries_h_planes: bool, log_n: usize) -> usize {
    if carries_h_planes && natural < log_n {
        log_n
    } else {
        natural
    }
}
