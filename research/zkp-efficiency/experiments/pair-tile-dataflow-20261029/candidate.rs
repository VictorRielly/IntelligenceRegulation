//! Current-call public Eq sharing; every pair is independently evaluated.
use crate::field::{Fp,Fp2};
use crate::eq_table_msb;
pub struct Pair<'a> { pub xs:&'a[Fp], pub ys:&'a[Fp] }
pub struct Weights { point:Vec<Fp2>, eq:Vec<Fp2> }
impl Weights {
    pub fn new(point:&[Fp2])->Self { Self{point:point.to_vec(),eq:eq_table_msb(point)} }
    fn validate(&self, point:&[Fp2],pairs:&[Pair]) {
        assert_eq!(self.point,point);
        for p in pairs { assert_eq!(p.xs.len(),self.eq.len()); assert_eq!(p.ys.len(),self.eq.len()); }
    }
    pub fn serial(&self,point:&[Fp2],pairs:&[Pair])->Vec<Fp2> {
        self.validate(point,pairs);
        pairs.iter().map(|p| {
            let (mut a,mut b,mut c)=(Fp::ZERO,Fp::ZERO,Fp::ZERO);
            for ((e,x),y) in self.eq.iter().zip(p.xs).zip(p.ys) {
                a=a.add(e.c0.mul(*x)); b=b.add(e.c1.mul(*y));
                c=c.add(e.c0.add(e.c1).mul(x.add(*y)));
            }
            Fp2::new(a.add(b.mul(Fp(7))),c.sub(a).sub(b))
        }).collect()
    }
    pub fn tiled<const K:usize>(&self,point:&[Fp2],pairs:&[Pair])->Vec<Fp2> {
        assert!(K==1 || K==2 || K==4);
        self.validate(point,pairs);
        let mut out=Vec::with_capacity(pairs.len());
        for tile in pairs.chunks(K) {
            let (mut a,mut b,mut c)=([Fp::ZERO;K],[Fp::ZERO;K],[Fp::ZERO;K]);
            for (i,e) in self.eq.iter().enumerate() {
                // One canonical public addition per coefficient and tile.
                let s=e.c0.add(e.c1);
                for (j,p) in tile.iter().enumerate() {
                    let (x,y)=(p.xs[i],p.ys[i]);
                    a[j]=a[j].add(e.c0.mul(x));b[j]=b[j].add(e.c1.mul(y));
                    c[j]=c[j].add(s.mul(x.add(y)));
                }
            }
            for j in 0..tile.len() {out.push(Fp2::new(a[j].add(b[j].mul(Fp(7))),c[j].sub(a[j]).sub(b[j])));}
        }
        out
    }
}
