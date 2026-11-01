//! R13 public output-channel coefficients are folded at Boolean channels.
//! Multiplying two interpolated values afterwards would change the relation.
use super::accuracy_public::{AccuracyPublic,Geometry};
use super::shape::Shape;
use crate::field::Fp2;
use crate::mle::{fold_rows_i8,fold_cols_i8};

#[derive(Clone,Copy,Debug,PartialEq,Eq)]
pub(crate) enum Site { Q,K,V,O,Gate,Up,Down }
#[derive(Clone,Copy,Debug,PartialEq,Eq)]
pub(crate) enum Axis { Rows,Columns }

/// Only the public data's validator admits coefficients. This helper maps
/// their logical output channels into the native padded/head-permuted axis;
/// the outer profile gate must also check stack, registry and calibration.
pub(crate) fn coefficients(sh:&Shape,a:&AccuracyPublic,site:Site)->Result<Vec<u64>,String> {
    let geo=Geometry{width:sh.width,query_width:sh.q_width(),kv_width:sh.kv_heads*sh.head_dim,hidden:sh.hidden};
    if geo!=a.geometry() {return Err("R13 matrix fold: geometry context mismatch".into());}
    let m=a.multipliers();
    if site==Site::Q {
        let mut out=vec![0;sh.q_pad()];
        for h in 0..sh.q_heads {for i in 0..sh.head_dim {
            out[sh.head_slot(h)*sh.head_dim+i]=m.q[h*sh.head_dim+i] as u64;
        }}
        return Ok(out);
    }
    let (words,len):(Vec<u64>,usize)=match site {
        Site::Q=>unreachable!(),
        Site::K=>(m.k.iter().map(|&v|v as u64).collect(),geo.kv_width),
        Site::V=>(m.v.iter().map(|&v|v as u64).collect(),geo.kv_width),
        Site::O=>(m.o.iter().map(|&v|v as u64).collect(),sh.d_pad),
        Site::Gate=>(a.folds().gate.multipliers.clone(),sh.f_pad),
        Site::Up=>(m.u.iter().map(|&v|v as u64).collect(),sh.f_pad),
        Site::Down=>(m.d.iter().map(|&v|v as u64).collect(),sh.d_pad),
    };
    let mut out=words;out.resize(len,0);Ok(out)
}

/// [ZK60-METAL M8] `matrix.contains(&i8::MIN)`, over 1 MiB chunks in
/// parallel: the same predicate (and so the same refusal), without one thread
/// scanning every weight of the layer at every fold (an 8B layer is 218 MB)
fn has_i8_min(matrix:&[i8])->bool {
    use rayon::prelude::*;
    matrix.par_chunks(1<<20).any(|c|c.contains(&i8::MIN))
}

pub(crate) fn fold(
    matrix:&[i8],rows:usize,cols:usize,axis:Axis,coefficients:&[u64],eq:&[Fp2],
)->Result<Vec<Fp2>,String> {
    let outputs=if axis==Axis::Rows {rows} else {cols};
    if !rows.is_power_of_two() || !cols.is_power_of_two() || rows.checked_mul(cols)!=Some(matrix.len())
        || outputs!=coefficients.len() || outputs!=eq.len() || coefficients.iter().any(|&m|m>1<<14)
        || has_i8_min(matrix) {
        return Err("R13 matrix fold: matrix/axis/coefficients outside the declared class".into());
    }
    let weighted:Vec<Fp2>=eq.iter().zip(coefficients).map(|(&e,&m)|e.mul_base(Fp2::from_i64(m as i64).c0)).collect();
    Ok(match axis {
        Axis::Rows=>fold_rows_i8(matrix,rows,cols,&weighted),
        Axis::Columns=>fold_cols_i8(matrix,rows,cols,&weighted),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::private_block::accuracy_precision::{Stack,BaseShifts};
    use crate::private_block::accuracy_public::Multipliers;
    use crate::private_block::accuracy_groups::Group;
    use crate::private_block::accuracy_tables::silu_table;
    use crate::mle::eq_table_msb;

    fn fixture()->(Shape,AccuracyPublic) {
        let sh=Shape::new("R13 scaled-fold fixture","r13-scaled-fold-fixture",32,48,6,6,8,2,8,8,9,13,None,None,None,None).unwrap();
        let values=|n:usize,max:usize|(0..n).map(|i|(i%max+1) as u16).collect();
        let m=Multipliers{q:values(48,32),k:values(16,32),v:values(16,64),o:values(48,256),
            g:values(6,64),u:values(6,16),d:values(48,64)};
        let groups=vec![Group{e_in:-4,e_out:-13},Group{e_in:-1,e_out:-11}];
        let tables=groups.iter().map(|g|silu_table(g.e_in,g.e_out,12).unwrap()).collect();
        let data=AccuracyPublic::new(Stack::LowH24,Geometry{width:48,query_width:48,kv_width:16,hidden:6},
            BaseShifts{norm_tn:10,qkv:8,score:6,pv:9,ao:7,gate:8,up:0,product:14,down:6},
            (-3,-11),m,groups,vec![0,1,0,1,0,1],tables).unwrap();
        (sh,data)
    }

    #[test]
    fn every_axis_uses_exact_channel_coefficients_and_query_head_permutation() {
        let (sh,a)=fixture();
        for site in [Site::Q,Site::K,Site::V,Site::O,Site::Gate,Site::Up,Site::Down] {
            let c=coefficients(&sh,&a,site).unwrap();
            if site==Site::Q {
                for h in 0..sh.q_heads {for i in 0..sh.head_dim {
                    assert_eq!(c[sh.head_slot(h)*sh.head_dim+i],a.multipliers().q[h*sh.head_dim+i] as u64);
                }}
                assert!(c[24..32].iter().chain(&c[56..64]).all(|&v|v==0));
            } else {
                let expected:Vec<u64>=match site {Site::K=>&a.multipliers().k,Site::V=>&a.multipliers().v,
                    Site::O=>&a.multipliers().o,Site::Up=>&a.multipliers().u,Site::Down=>&a.multipliers().d,
                    Site::Gate=>{assert_eq!(&c[..6],a.folds().gate.multipliers.as_slice());assert!(c[6..].iter().all(|&v|v==0));continue},
                    Site::Q=>unreachable!()}.iter().map(|&v|v as u64).collect();
                assert_eq!(&c[..expected.len()],&expected);assert!(c[expected.len()..].iter().all(|&v|v==0));
            }
        }
    }

    #[test]
    fn all_seven_native_matrix_folds_equal_an_independent_scaled_coefficient_sum() {
        let (sh,a)=fixture();
        for site in [Site::Q,Site::K,Site::V,Site::O,Site::Gate,Site::Up,Site::Down] {
            let coefficients=coefficients(&sh,&a,site).unwrap();
            let axis=if matches!(site,Site::Gate|Site::Up|Site::Down) {Axis::Columns} else {Axis::Rows};
            let outputs=coefficients.len();let inner=if matches!(site,Site::O) {sh.q_pad()} else if site==Site::Down {sh.f_pad} else {sh.d_pad};
            let (rows,cols)=if axis==Axis::Rows {(outputs,inner)} else {(inner,outputs)};
            let matrix:Vec<i8>=(0..rows*cols).map(|i|((i*73+19)%255) as i16-127).map(|v|v as i8).collect();
            let r:Vec<_>=(0..outputs.trailing_zeros()).map(|i|Fp2::from_i64(i as i64+2)).collect();
            let eq=eq_table_msb(&r);
            let got=fold(&matrix,rows,cols,axis,&coefficients,&eq).unwrap();
            let expected:Vec<_>=(0..inner).map(|i| (0..outputs).fold(Fp2::ZERO,|acc,j| {
                let w=matrix[if axis==Axis::Rows {j*cols+i} else {i*cols+j}];
                acc.add(eq[j].mul(Fp2::from_i64(w as i64*coefficients[j] as i64)))
            })).collect();
            assert_eq!(got,expected,"{site:?}");
        }
    }

    #[test]
    fn multiplying_interpolants_after_folding_is_rejected_by_the_differential_case() {
        let eq=eq_table_msb(&[Fp2::from_i64(2)]);
        let correct=fold(&[1,3],2,1,Axis::Rows,&[2,5],&eq).unwrap()[0];
        let wrong=fold_rows_i8(&[1,3],2,1,&eq)[0].mul(eq[0].mul(Fp2::from_i64(2)).add(eq[1].mul(Fp2::from_i64(5))));
        assert_ne!(correct,wrong);
        assert_eq!(correct,Fp2::from_i64(28));
        assert!(fold(&[-128,3],2,1,Axis::Rows,&[2,5],&eq).is_err());
        assert!(fold(&[1,3],2,1,Axis::Rows,&[2,1<<15],&eq).is_err());
        assert!(fold(&[1,3],2,1,Axis::Rows,&[2],&eq).is_err());
    }
}
