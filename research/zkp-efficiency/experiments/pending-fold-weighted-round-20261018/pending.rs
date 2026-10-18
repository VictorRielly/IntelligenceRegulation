// Research-only public-shape adapter. No transcript or mask randomness here.
// A message is measured BEFORE its own challenge can enter the state.
#[derive(Default,Clone,Debug)]
pub struct Traffic { pub reads:usize,pub writes:usize,pub nodes:usize,pub folds:usize }
fn pending_halves(v:&mut[Fp2],old:usize,point:&[Fp2],r:Fp2,t:&mut Traffic)->(Fp2,Fp2) {
    fn walk(v:&mut[Fp2],h:usize,q:usize,p:&[Fp2],i:usize,w:Fp2,r:Fp2,a:&mut[Fp2;2],t:&mut Traffic) {
        if p.is_empty() {
            // Four original values are read before the two distinct low-half writes.
            let x=v[i];let y=v[h+i];let z=v[q+i];let u=v[h+q+i];
            let lo=x.add(r.mul(y.sub(x)));let hi=z.add(r.mul(u.sub(z)));
            v[i]=lo;v[q+i]=hi;
            a[0]=a[0].add(w.mul(lo));a[1]=a[1].add(w.mul(hi));
            t.reads+=4;t.writes+=2;t.folds+=2;return;
        }
        t.nodes+=1;
        walk(v,h,q,&p[1..],2*i,w.mul(Fp2::ONE.sub(p[0])),r,a,t);
        walk(v,h,q,&p[1..],2*i+1,w.mul(p[0]),r,a,t);
    }
    let mut a=[Fp2::ZERO;2];walk(v,old/2,old/4,point,0,Fp2::ONE,r,&mut a,t);(a[0],a[1])
}
pub struct PendingRows {
    n:usize,c:usize,k:usize,l:usize,j:usize,width:usize,
    values:Vec<Fp2>,points:Vec<Fp2>,prefix:Vec<Fp2>,
    pending:Option<Fp2>,awaiting:bool,terms:Option<Vec<[Fp2;3]>>,
    pub traffic:Traffic,
}
impl PendingRows {
    pub fn new(n:usize,c:usize,v:Vec<Fp2>,points:Vec<Fp2>,cp:&[Fp2])->Result<Self,u32> {
        if n==0||!n.is_power_of_two()||n>1<<15||c==0||c>128{return Err(11);}
        let k=n.trailing_zeros()as usize;let l=c.next_power_of_two().trailing_zeros()as usize;
        if n*c>1<<20||v.len()!=n*c||points.len()!=c*k||cp.len()!=l{return Err(12);}
        let prefix=(0..c).map(|i|bool_weight(i,cp)).collect();
        let mut st=Self{n,c,k,l,j:0,width:n,values:v,points,prefix,pending:None,awaiting:false,terms:None,traffic:Traffic::default()};
        if k+l==0 {st.row_tail();} // Native finals(&self) has no opportunity to drain.
        Ok(st)
    }
    fn row_tail(&mut self) {
        if let Some(r)=self.pending {
            assert_eq!(self.width,2);
            for col in 0..self.c {
                let at=col*self.n;let a=self.values[at];let b=self.values[at+1];
                self.values[at]=a.add(r.mul(b.sub(a)));
                self.traffic.reads+=2;self.traffic.writes+=1;self.traffic.folds+=1;
            }
            self.width=1;self.pending=None;
        }
        if self.terms.is_none() {
            let mut terms=vec![[Fp2::ZERO;3];self.c.next_power_of_two()];
            for col in 0..self.c {terms[col]=[self.prefix[col],Fp2::ONE,self.values[col*self.n]];}
            self.terms=Some(terms);self.width=self.c.next_power_of_two();
        }
    }
    pub fn measure(&mut self)->Result<[Fp2;4],u32> {
        if self.awaiting||self.j>=self.k+self.l{return Err(21);}
        let mut sums=[Fp2::ZERO;4];
        if self.j<self.k {
            for col in 0..self.c {
                let v=&mut self.values[col*self.n..col*self.n+self.width];
                let p=&self.points[col*self.k..(col+1)*self.k];
                let (a,b)=if let Some(r)=self.pending {
                    pending_halves(v,self.width,&p[self.j+1..],r,&mut self.traffic)
                } else {
                    let(a,b,nodes)=weighted_halves(v,self.width/2,&p[self.j+1..]);
                    self.traffic.reads+=self.width;self.traffic.nodes+=nodes;(a,b)
                };
                let d=b.sub(a);
                for t in 0..4 {let x=Fp2::from_u64(t as u64);
                    sums[t]=sums[t].add(self.prefix[col].mul(eq_bit(p[self.j],x)).mul(a.add(x.mul(d))));}
            }
            if self.pending.is_some(){self.width/=2;self.pending=None;}
        } else {
            self.row_tail();let half=self.width/2;let ts=self.terms.as_ref().unwrap();
            for i in 0..half {
                let a=ts[i];let d=std::array::from_fn::<_,3,_>(|f|ts[half+i][f].sub(a[f]));
                for t in 0..4 {let x=Fp2::from_u64(t as u64);
                    sums[t]=sums[t].add(product(std::array::from_fn(|f|a[f].add(x.mul(d[f])))));}
            }
        }
        self.awaiting=true;Ok(sums)
    }
    pub fn bind(&mut self,r:Fp2)->Result<(),u32> {
        if !self.awaiting||self.j>=self.k+self.l{return Err(22);}
        if self.j<self.k {
            if self.pending.is_some(){return Err(23);}
            for col in 0..self.c {let p=self.points[col*self.k+self.j];
                self.prefix[col]=self.prefix[col].mul(eq_bit(p,r));}
            self.pending=Some(r);
        } else {
            let half=self.width/2;let ts=self.terms.as_mut().unwrap();
            for i in 0..half {ts[i]=std::array::from_fn(|f|ts[i][f].add(r.mul(ts[half+i][f].sub(ts[i][f]))));}
            self.width=half;
        }
        self.j+=1;self.awaiting=false;
        if self.j==self.k+self.l {self.row_tail();} // Last fold drains before immutable finals.
        Ok(())
    }
    pub fn finish(&mut self)->Result<[Fp2;3],u32> {
        if self.awaiting||self.j!=self.k+self.l{return Err(24);}
        self.row_tail();Ok(self.terms.as_ref().unwrap()[0])
    }
}
// Exact shape of the captured native seam; no host transcript implementation.
pub trait SumcheckRounds {
    fn n_vars(&self) -> usize;
    fn degree(&self) -> usize;
    fn round(&mut self, j: usize) -> Vec<Fp2>;
    fn fold(&mut self, r: Fp2);
    fn finals(&self) -> Vec<Fp2>;
}
impl SumcheckRounds for PendingRows {
    fn n_vars(&self)->usize {self.k+self.l}
    fn degree(&self)->usize {3}
    fn round(&mut self,j:usize)->Vec<Fp2>{assert_eq!(j,self.j);self.measure().unwrap().to_vec()}
    fn fold(&mut self,r:Fp2){self.bind(r).unwrap();}
    fn finals(&self)->Vec<Fp2>{
        assert_eq!(self.j,self.k+self.l);assert!(!self.awaiting&&self.pending.is_none());
        self.terms.as_ref().expect("last fold must drain")[0].to_vec()
    }
}
#[no_mangle]
pub unsafe extern "C" fn pending(n:usize,c:usize,vs:*const u64,nv:usize,
    ps:*const u64,np:usize,cp:*const u64,nc:usize,rs:*const u64,kr:usize,
    out:*mut u64,counts:*mut usize)->u32 {
    if nv>1<<20||np>4096||nc>20||kr>20{return 13;}
    let mut st=match PendingRows::new(n,c,read_fp(vs,nv),read_fp(ps,np),&read_fp(cp,nc)){Ok(x)=>x,Err(e)=>return e};
    if kr!=st.k+st.l{return 12;}
    let challenges=read_fp(rs,kr);let mut flat=Vec::new();
    // Sequence deliberately prevents the current challenge reaching measure().
    for (j,r) in challenges.into_iter().enumerate() {flat.extend(st.round(j));st.fold(r);}
    flat.extend(st.finals());write_fp(out,&flat);
    for (j,x) in [st.traffic.reads,st.traffic.writes,st.traffic.nodes,st.traffic.folds].iter().enumerate(){*counts.add(j)=*x;}0
}
#[no_mangle]
pub extern "C" fn lifecycle_controls()->u32 {
    let mut s=PendingRows::new(4,1,vec![Fp2::ONE;4],vec![Fp2::ONE;2],&[]).unwrap();let mut n=0;
    if s.bind(Fp2::ONE).is_err(){n+=1;}
    if s.finish().is_err(){n+=1;}
    s.measure().unwrap();if s.measure().is_err(){n+=1;}
    if s.finish().is_err(){n+=1;}
    s.bind(Fp2::ONE).unwrap();if s.bind(Fp2::ZERO).is_err(){n+=1;}
    s.measure().unwrap();s.bind(Fp2::ONE).unwrap();let a=s.finish().unwrap();
    if s.finish().unwrap()==a{n+=1;}
    if s.measure().is_err(){n+=1;}
    if s.bind(Fp2::ONE).is_err(){n+=1;}
    n
}
