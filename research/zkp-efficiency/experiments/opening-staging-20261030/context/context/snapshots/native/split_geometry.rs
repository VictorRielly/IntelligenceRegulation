//! R14 global-index gathers, public folds and native source-coordinate maps.
//! No polynomial/profile dispatch is activated here.
#![allow(dead_code)]
use super::accuracy_fold::Axis;
use super::argument::Coord;
use super::layout::Dom;
use super::shape::Shape;
use super::split_layout::{Extent,Plane,SplitLayout};
use crate::field::{Fp,Fp2};
use crate::mle::eq_table_msb;

fn lg(n:usize)->Result<usize,String> {
    if !n.is_power_of_two(){return Err("R14 geometry: a power-of-two axis is required".into());}
    Ok(n.trailing_zeros() as usize)
}

fn axis(base:&Shape,split:&SplitLayout,plane:&Plane)->Result<(usize,Extent),String> {
    use super::split_layout::Part;
    let (pad,pieces)=match plane.domain {Dom::D=>(base.d_pad,&split.d),Dom::F=>(base.f_pad,&split.f),
        _=>return Err("R14 geometry: this plane has no split feature axis".into())};
    let i=match plane.part {Part::Wide=>0,Part::Narrow=>1,Part::Whole=>return Err("R14 geometry: a split role has no piece".into())};
    Ok((pad,pieces[i]))
}

/// Gather the true global lanes of ONE numeric role. Histogram roles are
/// deliberately refused: protocol must rebuild global counts after gathering.
pub(crate) fn gather_numeric_plane(base:&Shape,split:&SplitLayout,parent:usize,words:&[i64])->Result<Vec<(usize,Vec<i64>)>,String> {
    let domains=base.a_plane_doms();let dom=*domains.get(parent).ok_or("R14 gather: undeclared logical role")?;
    if dom==Dom::Tab {return Err("R14 gather: global histograms must be rebuilt from piece queries".into());}
    if words.len()!=base.size(dom){return Err("R14 gather: reference plane length differs from its declared domain".into());}
    let mut result=Vec::new();
    for (physical,p) in split.a.iter().enumerate().filter(|(_,p)|p.parent==parent) {
        let data=if matches!(dom,Dom::D|Dom::F) {
            let(pad,e)=axis(base,split,p)?;let mut out=Vec::with_capacity(base.tokens*e.width);
            for t in 0..base.tokens {out.extend_from_slice(&words[t*pad+e.start..t*pad+e.start+e.width]);}out
        }else{words.to_vec()};
        if data.len()!=1usize<<p.log {return Err("R14 gather: physical role length differs from its domain".into());}
        result.push((physical,data));
    }
    if result.is_empty(){return Err("R14 gather: logical role has no physical source".into());}Ok(result)
}

/// Native private table coordinates: broadcast over omitted leading feature
/// variables, retaining every token coordinate. The private functional is NOT
/// multiplied by a lift coefficient; the public factor carries the selector.
pub(crate) fn source_coords(base:&Shape,split:&SplitLayout,p:&Plane,large_width:usize,fixed_token:Option<&[Fp2]>)->Result<Vec<Coord>,String> {
    let(_,e)=axis(base,split,p)?;let lt=lg(base.t_pad)?;let large=lg(large_width)?;let own=lg(e.width)?;
    if own>large {return Err("R14 map: source feature axis exceeds the slot axis".into());}
    let mut coords=Vec::with_capacity(p.log);
    let start=if let Some(point)=fixed_token {
        if point.len()!=lt {return Err("R14 map: fixed token point arity".into());}
        coords.extend(point.iter().copied().map(Coord::Fixed));0
    }else{coords.extend((0..lt).map(Coord::Rho));lt};
    coords.extend((start+large-own..start+large).map(Coord::Rho));
    if coords.len()!=p.log {return Err("R14 map: projected source arity differs".into());}Ok(coords)
}

/// The ONE norm equality factor; its appended zero coordinates implement the
/// selector. Do not materialize a separate public gate table.
pub(crate) fn norm_eq_point(token:&[Fp2],large_width:usize,own_width:usize)->Result<Vec<Fp2>,String> {
    let large=lg(large_width)?;let own=lg(own_width)?;
    if own>large {return Err("R14 norm gate: own width exceeds the common cube".into());}
    let mut point=token.to_vec();point.resize(token.len()+large-own,Fp2::ZERO);Ok(point)
}

/// Fold a real global submatrix, with output-channel coefficients applied
/// BEFORE interpolation. Axis describes the stored matrix orientation, just
/// as in R13; neither channel index is reset at a piece boundary.
pub(crate) fn public_fold_piece(matrix:&[i8],rows:usize,cols:usize,orientation:Axis,
    output:Extent,input:Extent,coefficients:&[u64],point:&[Fp2])->Result<Vec<Fp2>,String> {
    let(out_len,in_len)=match orientation {Axis::Rows=>(rows,cols),Axis::Columns=>(cols,rows)};
    let in_end=input.start.checked_add(input.width).ok_or("R14 fold: input extent overflow")?;
    let out_end=output.start.checked_add(output.width).ok_or("R14 fold: output extent overflow")?;
    if rows.checked_mul(cols)!=Some(matrix.len())||coefficients.len()!=out_len
        ||out_end>out_len||in_end>in_len||point.len()!=lg(output.width)?
        ||coefficients.iter().any(|&c|c>1<<14)||matrix.contains(&i8::MIN) {
        return Err("R14 fold: matrix/axis/coefficient/extent outside the declared class".into());
    }
    lg(input.width)?;
    let weights=eq_table_msb(point).into_iter().enumerate().map(|(j,e)|e.mul_base(Fp::new(coefficients[output.start+j]))).collect::<Vec<_>>();
    Ok((0..input.width).map(|i| {
        let gi=input.start+i;let mut sum=Fp2::ZERO;
        for (j,w) in weights.iter().enumerate() {
            let gj=output.start+j;
            let v=match orientation {Axis::Rows=>matrix[gj*cols+gi],Axis::Columns=>matrix[gi*cols+gj]};
            if v!=0 {sum=sum.add(w.mul_base(Fp::from_i64(v as i64)));}
        }sum
    }).collect())
}

pub(crate) fn zero_lift_public_fold(fold:&[Fp2],large_width:usize)->Result<Vec<Fp2>,String> {
    lg(fold.len())?;lg(large_width)?;
    if fold.len()>large_width {return Err("R14 weight gate: source exceeds common inner cube".into());}
    let mut out=vec![Fp2::ZERO;large_width];out[..fold.len()].copy_from_slice(fold);
    if out[fold.len()..].iter().any(|&v|v!=Fp2::ZERO){return Err("R14 weight gate: nonzero omitted half-cube".into());}
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use super::super::argument::{self,Cm,Priv};
    use super::super::layout::*;
    use super::super::shape::{self,NormCalibration};
    use super::super::split_layout::Part;
    use crate::mle::eval_mle_ext;
    fn f(x:usize)->Fp2 {Fp2::new(Fp::new((x*7+3) as u64),Fp::new((x*11+5) as u64))}
    fn setup()->(Shape,SplitLayout) {
        let cal=NormCalibration{tn:9,cn_a:100,cn_m:100,ceps:1,sh_ao:7,sh_qkv:8,sh_s:6,sh_o:9,sh_g:8,sh_h:14,sh_z:6};
        let sh=Shape::accuracy_trained(shape::R13_SHIELD_T128_H24,&cal,9,20).unwrap();
        let split=SplitLayout::new(&sh,[2048,1024],[8192,1024]).unwrap();(sh,split)
    }
    #[test]
    fn gather_all_true_numeric_roles_preserves_global_token_feature_indices() {
        let(sh,split)=setup();let ids=Ids::new(&sh).unwrap();let mut checked=0;
        for (parent,dom) in sh.a_plane_doms().into_iter().enumerate() {
            if !matches!(dom,Dom::D|Dom::F){continue;}
            let pad=if dom==Dom::D {sh.d_pad}else{sh.f_pad};
            let words=(0..sh.size(dom)).map(|i|((i*37+parent*11)%65521) as i64-32760).collect::<Vec<_>>();
            let parts=gather_numeric_plane(&sh,&split,parent,&words).unwrap();assert_eq!(parts.len(),2);
            for (physical,v) in parts {
                let(_,e)=axis(&sh,&split,&split.a[physical]).unwrap();
                for t in 0..sh.tokens {for j in 0..e.width {assert_eq!(v[t*e.width+j],words[t*pad+e.start+j]);checked+=1;}}
            }
        }
        assert_eq!(checked,sh.tokens*(3072*39+9216*16));
        assert!(gather_numeric_plane(&sh,&split,ids.at(A_MU8),&vec![0;sh.size(Dom::Tab)]).unwrap_err().contains("histograms"));
        assert!(gather_numeric_plane(&sh,&split,ids.at(A_X),&[0]).is_err());
    }
    #[test]
    fn native_private_broadcast_maps_keep_fixed_and_moving_tokens() {
        let(sh,split)=setup();let ids=Ids::new(&sh).unwrap();let lt=sh.t_pad.trailing_zeros() as usize;
        for (parent,large) in [(ids.at(A_X),2048),(ids.at(A_H16),8192)] {
            let p=split.plane(false,parent,Part::Narrow).unwrap();
            let source=(0..1usize<<p.log).map(|i|Fp::from_i64(((i*37)%251) as i64-125)).collect::<Vec<_>>();
            for fixed in [false,true] {
                let token=(0..lt).map(f).collect::<Vec<_>>();let coords=source_coords(&sh,&split,p,large,fixed.then_some(token.as_slice())).unwrap();
                let vars=large.trailing_zeros() as usize+if fixed {0}else{lt};
                let table=argument::priv_table(&Priv{cm:Cm::A,slices:vec![(0,Fp2::ONE)],log:p.log,coords:coords.clone(),mask_row:0,ext_round:0},&source,vars);
                let mut rho=(0..vars).map(|i|f(i+19)).collect::<Vec<_>>();
                let point=|rho:&[Fp2]|coords.iter().map(|c|match c {Coord::Rho(k)=>rho[*k],Coord::Fixed(v)=>*v,Coord::Flip(k)=>Fp2::ONE.sub(rho[*k])}).collect::<Vec<_>>();
                let direct=source.iter().copied().map(Fp2::from_base).collect::<Vec<_>>();
                assert_eq!(eval_mle_ext(&table,&rho),eval_mle_ext(&direct,&point(&rho)));
                // At the omitted bit=1 private data is STILL broadcast; no
                // hidden sigma multiplier or zero-functional special case.
                rho[if fixed {0}else{lt}]=Fp2::ONE;
                assert_eq!(eval_mle_ext(&table,&rho),eval_mle_ext(&direct,&point(&rho)));
                assert_ne!(eval_mle_ext(&table,&rho),Fp2::ZERO);
            }
        }
    }
    #[test]
    fn both_matrix_orientations_use_global_coefficients_and_one_public_gate() {
        for orientation in [Axis::Rows,Axis::Columns] {
            let(rows,cols)=(16,32);let(out_len,in_len)=match orientation {Axis::Rows=>(rows,cols),Axis::Columns=>(cols,rows)};
            let m=(0..rows*cols).map(|i|((i*17+i/cols*31)%255) as i16-127).map(|i|i as i8).collect::<Vec<_>>();
            let coefficients=(0..out_len).map(|j|((j*37+5)%16384+1) as u64).collect::<Vec<_>>();
            let out=Extent{start:out_len/2,width:out_len/4};let input=Extent{start:in_len/2,width:in_len/4};
            let point=(0..out.width.trailing_zeros() as usize).map(f).collect::<Vec<_>>();
            let mut weights=vec![Fp2::ZERO;out_len];weights[out.start..out.start+out.width].copy_from_slice(&eq_table_msb(&point));
            let full=super::super::accuracy_fold::fold(&m,rows,cols,orientation,&coefficients,&weights).unwrap();
            let part=public_fold_piece(&m,rows,cols,orientation,out,input,&coefficients,&point).unwrap();
            assert_eq!(part,full[input.start..input.start+input.width]);
            let mut wrong_coeff=coefficients.clone();for j in out.start..out.start+out.width {wrong_coeff[j]=coefficients[j-out.start];}
            assert_ne!(part,public_fold_piece(&m,rows,cols,orientation,out,input,&wrong_coeff,&point).unwrap());
            let lifted=zero_lift_public_fold(&part,input.width*8).unwrap();
            assert_eq!(&lifted[..part.len()],part.as_slice());assert!(lifted[part.len()..].iter().all(|&v|v==Fp2::ZERO));
            let mut bad=m.clone();bad[0]=i8::MIN;assert!(public_fold_piece(&bad,rows,cols,orientation,out,input,&coefficients,&point).is_err());
        }
        let rt=vec![f(1),f(2)];let point=norm_eq_point(&rt,32,4).unwrap();assert_eq!(&point[rt.len()..],&[Fp2::ZERO;3]);
        let cube=argument::eq_cube(&eq_table_msb(&point),rt.len()+5,0);
        for (i,v) in cube.iter().enumerate() {if (i>>2)&7!=0 {assert_eq!(*v,Fp2::ZERO);}}
        let one=Fp2::ONE;let eval=|x:usize,separate:bool| {
            let e=Fp2::from_u64(x as u64);let eq=one.sub(e).mul(f(3));let y=one.sub(e).mul(f(5)).add(e.mul(f(7)));
            if separate {eq.mul(one.sub(e).mul(f(11))).mul(y.mul(y))}else{eq.mul(y.mul(y))}
        };
        let diff=|mut v:Vec<Fp2>|{for _ in 0..4 {v=v.windows(2).map(|w|w[1].sub(w[0])).collect();}v[0]};
        assert_eq!(diff((0..5).map(|e|eval(e,false)).collect()),Fp2::ZERO);
        assert_ne!(diff((0..5).map(|e|eval(e,true)).collect()),Fp2::ZERO);
    }
}
