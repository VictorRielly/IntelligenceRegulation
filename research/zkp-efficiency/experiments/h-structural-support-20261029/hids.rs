pub(crate) struct HIds {
    doms: Vec<Dom>,
    first_l: usize,
    first_d: usize,
    first_q: usize,
    first_kv: usize,
    first_s: usize,
    first_f: usize,
    sexp: usize,
    fact: usize,
    gu8: usize,
    u: usize,
    /// NATIVE R9 (D30): the score entry's tuple helper, the dictionary's
    /// first byte helper and its TABLE helper (`usize::MAX` off a DD profile)
    stuple: usize,
    first_dd: usize,
    gdd: usize,
}

impl HIds {
    pub(crate) fn new(sh: &super::shape::Shape) -> Result<HIds, String> {
        let mut doms: Vec<Dom> = Vec::new();
        let seg = |doms: &mut Vec<Dom>, dom: Dom, n: usize| -> usize {
            let first = doms.len();
            for _ in 0..n {
                doms.push(dom);
            }
            first
        };
        // the plane order of `Shape::h_plane_doms`: the five lookup-domain
        // helper blocks, the exponential pair's own helper inside `Dom::S`,
        // the feed-forward helpers, the activation pair's own helper, the
        // three table helpers and the zero-sum pair
        let first_l = seg(&mut doms, Dom::L, sh.helpers(Dom::L));
        let first_d = seg(&mut doms, Dom::D, sh.helpers(Dom::D));
        let first_q = seg(&mut doms, Dom::Q, sh.helpers(Dom::Q));
        let first_kv = seg(&mut doms, Dom::Kv, sh.helpers(Dom::Kv));
        let first_s = seg(&mut doms, Dom::S, sh.helpers(Dom::S));
        let sexp = seg(&mut doms, Dom::S, 1);
        let dd = sh.dd_cap > 0;
        let stuple = if dd { seg(&mut doms, Dom::S, 1) } else { usize::MAX };
        let first_f = seg(&mut doms, Dom::F, sh.helpers(Dom::F));
        let fact = seg(&mut doms, Dom::F, 1);
        let (first_dd, gdd) = if dd { (seg(&mut doms, Dom::Dd, sh.helpers(Dom::Dd)), seg(&mut doms, Dom::Dd, 1)) } else { (usize::MAX, usize::MAX) };
        let gu8 = seg(&mut doms, Dom::Tab, 3);
        let u = seg(&mut doms, Dom::Tab, 1);
        if doms != sh.h_plane_doms() {
            return Err("private block: this shape's H plane list differs from the pinned one".into());
        }
        Ok(HIds { doms, first_l, first_d, first_q, first_kv, first_s, first_f, sexp, fact, gu8, u, stuple, first_dd, gdd })
    }

    /// the `k`-th LogUp helper of a lookup domain
    pub(crate) fn helper(&self, dom: Dom, k: usize) -> usize {
        self.first_helper(dom) + k
    }
    /// the first LogUp helper plane of a lookup domain (the replacement for
    /// the literal half of [`helpers`])
    pub(crate) fn first_helper(&self, dom: Dom) -> usize {
        match dom {
            Dom::L => self.first_l,
            Dom::D => self.first_d,
            Dom::Q => self.first_q,
            Dom::Kv => self.first_kv,
            Dom::S => self.first_s,
            Dom::F => self.first_f,
            Dom::Dd => self.first_dd,
            _ => 0,
        }
    }
    /// the exponential pair's own helper (`H_SEXP` at the toy)
    pub(crate) fn sexp(&self) -> usize {
        self.sexp
    }
    /// the activation pair's own helper (`H_FACT` at the toy)
    pub(crate) fn fact(&self) -> usize {
        self.fact
    }
    /// the three table helpers, in the toy's order `(U8, exp, act)`
    pub(crate) fn table_helpers(&self) -> [usize; 3] {
        [self.gu8, self.gu8 + 1, self.gu8 + 2]
    }
    /// the zero-sum masking pair `u` (`H_U` at the toy)
    pub(crate) fn u(&self) -> usize {
        self.u
    }
    pub(crate) fn n_h(&self) -> usize {
        self.doms.len()
    }
    pub(crate) fn dom(&self, plane: usize) -> Dom {
        self.doms[plane]
    }
    /// the table helpers enter the value-0 LogUp identity with a negative sign
    /// — NATIVE R9 (D30 condition 3, CHECK.md P-2 / E-2): the dictionary's
    /// table helper too, in the SINGLE value-0 sum claim
    pub(crate) fn is_table(&self, plane: usize) -> bool {
        (self.gu8..self.gu8 + 3).contains(&plane) || (self.gdd != usize::MAX && plane == self.gdd)
    }
    /// NATIVE R9: the score entry's single tuple helper (a DD profile only)
    pub(crate) fn stuple(&self) -> usize {
        assert!(self.stuple != usize::MAX, "private block: the tuple helper asked of a shape without a dictionary");
        self.stuple
    }
    /// NATIVE R9: the dictionary's table helper `g` (a DD profile only)
    pub(crate) fn gdd(&self) -> usize {
        assert!(self.gdd != usize::MAX, "private block: the dictionary table helper asked of a shape without a dictionary");
        self.gdd
    }
}

