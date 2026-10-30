#![allow(dead_code)]
#[derive(Clone,Copy,Debug)] enum Dom {T,Ht,L,D,Q,Kv,S,F,Tab,Dd}
impl Dom {fn carries_h_planes(self)->bool {!matches!(self,Dom::T|Dom::Ht)}}
const LIMBS_ISQRT:usize=3; const U8_LEN:usize=256;
fn clog2(v:usize)->usize {assert!(v>0);v.next_power_of_two().trailing_zeros() as usize}
struct Shape {tokens:usize,width:usize,hidden:usize,q_heads:usize,head_dim:usize,kv_heads:usize,
 log_cols:usize,dd_cap:usize,t_pad:usize,d_pad:usize,h_pad:usize,f_pad:usize,frozen:bool}
impl Shape {fn carries_pad_rule(&self)->bool {!self.frozen}
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
    pub(crate) fn pads(&self, dom: Dom) -> bool {
        self.size(dom) != self.true_size(dom)
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
    pub(crate) fn n_slots(&self) -> usize {
        N_SLOTS + usize::from(self.dd_cap > 0)
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
