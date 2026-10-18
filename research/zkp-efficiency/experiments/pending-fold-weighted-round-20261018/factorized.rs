// Research arithmetic probe: row bits then column bits, both MSB first.
// Only rectangular PUBLIC shape padding is implicit. No private sparsity.
fn eq_bit(a:Fp2,b:Fp2)->Fp2 {
    Fp2::ONE.sub(a).mul(Fp2::ONE.sub(b)).add(a.mul(b))
}
fn bool_weight(i:usize, point:&[Fp2])->Fp2 {
    point.iter().enumerate().fold(Fp2::ONE,|w,(j,&r)|
        w.mul(if (i>>(point.len()-1-j))&1==1 {r}else{Fp2::ONE.sub(r)}))
}
// Generate suffix weights with a depth-first walk: O(log N) stack, no E table,
// no division (including when coordinates are 0, 1, or 1/2).
fn weighted_halves(v:&[Fp2],half:usize,point:&[Fp2])->(Fp2,Fp2,usize) {
    fn walk(v:&[Fp2],half:usize,p:&[Fp2],i:usize,w:Fp2,a:&mut[Fp2;2],nodes:&mut usize) {
        if p.is_empty() {a[0]=a[0].add(w.mul(v[i]));a[1]=a[1].add(w.mul(v[half+i]));return;}
        *nodes+=1;
        walk(v,half,&p[1..],i*2,w.mul(Fp2::ONE.sub(p[0])),a,nodes);
        walk(v,half,&p[1..],i*2+1,w.mul(p[0]),a,nodes);
    }
    let mut a=[Fp2::ZERO;2];let mut nodes=0;
    walk(v,half,point,0,Fp2::ONE,&mut a,&mut nodes);(a[0],a[1],nodes)
}
pub fn factorized_rounds(n:usize,c:usize,values:&mut[Fp2],points:&[Fp2],
    column_point:&[Fp2],challenges:&[Fp2])
    ->Result<(Vec<[Fp2;4]>,[Fp2;3],[usize;3]),u32> {
    if n==0||!n.is_power_of_two()||n>1<<15||c==0||c>128{return Err(11);}
    let k=n.trailing_zeros()as usize;let w=c.next_power_of_two();let l=w.trailing_zeros()as usize;
    if n*c>1<<20||values.len()!=n*c||points.len()!=c*k||column_point.len()!=l||challenges.len()!=k+l{return Err(12);}
    let mut prefix=(0..c).map(|col|bool_weight(col,column_point)).collect::<Vec<_>>();
    let mut width=n;let mut out=Vec::with_capacity(k+l);
    let mut row_pairs=0;let mut eq_nodes=0;let mut col_pairs=0;
    for j in 0..k {
        let half=width/2;let mut sums=[Fp2::ZERO;4];
        for col in 0..c {
            let v=&mut values[col*n..col*n+width];let p=&points[col*k..(col+1)*k];
            let(a,b,nodes)=weighted_halves(v,half,&p[j+1..]);eq_nodes+=nodes;row_pairs+=half;
            let d=b.sub(a);
            for t in 0..4 {let x=Fp2::from_u64(t as u64);
                sums[t]=sums[t].add(prefix[col].mul(eq_bit(p[j],x)).mul(a.add(x.mul(d))));}
            for i in 0..half {v[i]=v[i].add(challenges[j].mul(v[half+i].sub(v[i])));}
            prefix[col]=prefix[col].mul(eq_bit(p[j],challenges[j]));
        }
        out.push(sums);width=half;
    }
    // Once row bits are bound, E is a MIXTURE across column coordinates;
    // S is the non-Boolean MLE of the public active-column selector.
    let mut terms=vec![[Fp2::ZERO;3];w];
    for col in 0..c {terms[col]=[prefix[col],Fp2::ONE,values[col*n]];}
    width=w;
    for &r in &challenges[k..] {
        let half=width/2;let mut sums=[Fp2::ZERO;4];col_pairs+=half;
        for i in 0..half {
            let a=terms[i];let d=std::array::from_fn::<_,3,_>(|f|terms[half+i][f].sub(a[f]));
            for t in 0..4 {let x=Fp2::from_u64(t as u64);
                sums[t]=sums[t].add(product(std::array::from_fn(|f|a[f].add(x.mul(d[f])))));}
            terms[i]=std::array::from_fn(|f|a[f].add(r.mul(d[f])));
        }
        out.push(sums);width=half;
    }
    Ok((out,terms[0],[row_pairs,eq_nodes,col_pairs]))
}
#[no_mangle]
pub unsafe extern "C" fn factorized(n:usize,c:usize,vs:*const u64,nv:usize,
    ps:*const u64,np:usize,cp:*const u64,nc:usize,rs:*const u64,kr:usize,
    out:*mut u64,counts:*mut usize)->u32 {
    // Length caps before allocating; FFI buffers themselves are trusted test harness input.
    if nv>1<<20||np>4096||nc>20||kr>20{return 13;}
    let mut v=read_fp(vs,nv);let p=read_fp(ps,np);let cp=read_fp(cp,nc);let rs=read_fp(rs,kr);
    match factorized_rounds(n,c,&mut v,&p,&cp,&rs) {
        Ok((rounds,finals,ns))=>{let mut flat=rounds.into_iter().flatten().collect::<Vec<_>>();flat.extend(finals);
            write_fp(out,&flat);for(j,x)in ns.iter().enumerate(){*counts.add(j)=*x;}0},Err(e)=>e
    }
}
