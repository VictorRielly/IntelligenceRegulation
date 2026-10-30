//! R14 native typed piece inventory and slot declaration, before proof wiring.
//! B-gate keeps the native private functional unchanged. One joint commitment
//! contains each logical boundary's ordered piece rows. No profile is activated
//! by this module; actual polynomial/claim builders must match this declaration.
#![allow(dead_code)]
use super::layout::*;
use super::shape::Shape;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Part { Whole, Wide, Narrow }

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct Extent { pub start:usize, pub width:usize }

#[derive(Clone, Debug)]
pub(crate) struct Plane {
    pub parent:usize,
    pub domain:Dom,
    pub part:Part,
    /// First component's element offset. H's imaginary component follows it.
    pub offset:usize,
    pub log:usize,
    pub rows_per_component:usize,
}

#[derive(Clone, Debug)]
pub(crate) struct Slot {
    pub base:usize,
    pub part:Part,
    pub main:usize,
    pub ext:usize,
    pub degree:usize,
    pub a_sites:usize,
    pub h_sites:usize,
    pub endpoint_sites:usize,
    pub a_pairs:Vec<usize>,
    pub h_pairs:Vec<usize>,
}

#[derive(Clone, Debug)]
pub(crate) struct JointEndpoint {
    pub piece_offsets:[usize;2],
    pub piece_logs:[usize;2],
    pub data_rows:usize,
    pub external_rows:usize,
    pub internal_rows:usize,
}

#[derive(Clone, Debug)]
pub(crate) struct SplitLayout {
    pub tokens:usize,
    pub n:usize,
    pub d:[Extent;2],
    pub f:[Extent;2],
    pub a:Vec<Plane>,
    pub h:Vec<Plane>,
    pub slots:Vec<Slot>,
    pub a_data_rows:usize,
    pub h_data_rows:usize,
    pub a_rows:usize,
    pub h_rows:usize,
    pub m_rows:usize,
    pub endpoint:JointEndpoint,
}

fn lg(x:usize)->Result<usize,String> {
    if !x.is_power_of_two() {return Err("R14 split: domain is not a power of two".into());}
    Ok(x.trailing_zeros() as usize)
}

impl SplitLayout {
    pub(crate) fn new(base:&Shape,d:[usize;2],f:[usize;2])->Result<Self,String> {
        if base.accuracy_stack()!=super::accuracy_precision::Stack::LowH24 {
            return Err("R14 split: an explicit LOW+h24 base is required".into());
        }
        if d.iter().sum::<usize>()!=base.width||f.iter().sum::<usize>()!=base.hidden {
            return Err("R14 split: piece extents do not cover the true model/FFN axis".into());
        }
        for widths in [d,f] {
            lg(widths[0])?;lg(widths[1])?;
            if widths[0]<=widths[1]||widths[0]%widths[1]!=0 {
                return Err("R14 split: ordered wide/narrow extents required".into());
            }
            lg(widths[0]/widths[1])?;
        }
        let n=1usize<<base.log_cols;
        // The native global LogUp sum uses a single all-ones column key.
        // Every physical H data slice must span whole aligned rows.
        if [d[1],f[1]].into_iter().any(|w|base.tokens*w<n) {
            return Err("R14 split: every H-bearing piece must be at least one full row".into());
        }
        let de=[Extent{start:0,width:d[0]},Extent{start:d[0],width:d[1]}];
        let fe=[Extent{start:0,width:f[0]},Extent{start:f[0],width:f[1]}];
        let inventory=|domains:Vec<Dom>,components:usize|->Result<(Vec<Plane>,usize),String> {
            let mut planes=Vec::new();let mut row=0usize;
            for (parent,domain) in domains.into_iter().enumerate() {
                let pieces:Vec<(Part,usize)>=match domain {
                    Dom::D=>vec![(Part::Wide,base.tokens*d[0]),(Part::Narrow,base.tokens*d[1])],
                    Dom::F=>vec![(Part::Wide,base.tokens*f[0]),(Part::Narrow,base.tokens*f[1])],
                    _=>vec![(Part::Whole,base.size(domain))],
                };
                for (part,size) in pieces {
                    let log=lg(size)?;let rows=size.div_ceil(n).max(1);
                    if components==2&&(size<n||size%n!=0) {
                        return Err("R14 split: H source is not whole-row aligned".into());
                    }
                    planes.push(Plane{parent,domain,part,offset:row*n,log,rows_per_component:rows});
                    row+=components*rows;
                }
            }
            Ok((planes,row))
        };
        let(a,a_data_rows)=inventory(base.a_plane_doms(),1)?;
        let(h,h_data_rows)=inventory(base.h_plane_doms(),2)?;
        let(a0,h0)=base.claim_sites();let rounds=base.slots();
        let adom=|domain|base.a_plane_doms().into_iter().filter(|&d|d==domain).count();
        let mut slots=Vec::new();
        let mut push=|old:usize,part:Part,main:usize,asites:usize,hsites:usize,epsites:usize| {
            let(_,ext,mut degree)=rounds[old];
            // True D/F pieces need no padded-axis indicator. Norm gates stay
            // folded into the ONE public equality factor, including at e=1.
            if matches!(old,SC_SS|SC_SSM|SC_DZC)&&base.pads(Dom::D) {degree-=1;}
            if old==SC_FZC&&base.pads(Dom::F) {degree-=1;}
            slots.push(Slot{base:old,part,main,ext,degree,a_sites:asites,h_sites:hsites,
                endpoint_sites:epsites,a_pairs:Vec::new(),h_pairs:Vec::new()});
        };
        let ld=lg(d[0])?;let lf=lg(f[0])?;
        // This order is also the future argument builder's schedule: every
        // private initial scalar precedes its matching host zero-check.
        for old in [SC_SS,SC_SSM] {push(old,Part::Whole,lg(base.tokens)?+ld,2,0,0);}
        for old in [SC_TZC,SC_LZC,SC_RS] {push(old,Part::Whole,rounds[old].0,a0[old],h0[old],0);}
        for old in [SC_QMM,SC_KMM,SC_VMM] {push(old,Part::Whole,ld,2,0,0);}
        for old in [SC_SCORE,SC_PV] {push(old,Part::Whole,rounds[old].0,a0[old],h0[old],0);}
        for part in [Part::Wide,Part::Narrow] {push(SC_WO,part,rounds[SC_WO].0,1,0,0);}
        for old in [SC_GMM,SC_UMM] {for part in [Part::Wide,Part::Narrow] {push(old,part,ld,2,0,0);}}
        for part in [Part::Wide,Part::Narrow] {push(SC_DMM,part,lf,2,0,0);}
        for (part,width) in [(Part::Wide,d[0]),(Part::Narrow,d[1])] {
            push(SC_DZC,part,lg(base.tokens*width)?,adom(Dom::D)+2,base.helpers(Dom::D),0);
        }
        for old in [SC_QZC,SC_KVZC,SC_SZC] {push(old,Part::Whole,rounds[old].0,a0[old],h0[old],0);}
        for (part,width) in [(Part::Wide,f[0]),(Part::Narrow,f[1])] {
            push(SC_FZC,part,lg(base.tokens*width)?,adom(Dom::F),base.helpers(Dom::F)+1,0);
        }
        for old in [SC_TAB,SC_ZS] {push(old,Part::Whole,rounds[old].0,a0[old],h0[old],0);}
        for old in [SC_IO_IN,SC_IO_OUT] {for (part,width) in [(Part::Wide,d[0]),(Part::Narrow,d[1])] {
            push(old,part,lg(base.tokens*width)?,1,0,1);
        }}
        if base.dd_cap>0 {push(SC_DD,Part::Whole,rounds[SC_DD].0,a0[SC_DD],h0[SC_DD],0);}
        let(mut ar,mut hr)=(a_data_rows,h_data_rows);
        for s in &mut slots {
            if (s.main+s.ext)*s.degree+2>256 {return Err("R14 split: CFS message exceeds its native budget".into());}
            for _ in 0..s.a_sites {s.a_pairs.push(ar);ar+=2;}
            for _ in 0..s.h_sites {s.h_pairs.push(hr);hr+=2;}
        }
        let d0=base.tokens*d[0];let d1=base.tokens*d[1];
        if d0%n!=0||d1%n!=0 {return Err("R14 split: joint endpoint pieces are not whole rows".into());}
        let data_rows=(d0+d1)/n;
        let endpoint=JointEndpoint{piece_offsets:[0,d0],piece_logs:[lg(d0)?,lg(d1)?],data_rows,
            external_rows:data_rows+2*2+2+1,internal_rows:data_rows+2*4+2};
        let m_rows=2*slots.len()+4;
        let out=Self{tokens:base.tokens,n,d:de,f:fe,a,h,slots,a_data_rows,h_data_rows,
            a_rows:ar+2,h_rows:hr+2,m_rows,endpoint};
        out.audit(base)?;Ok(out)
    }

    pub(crate) fn plane(&self,h:bool,parent:usize,part:Part)->Result<&Plane,String> {
        let list=if h {&self.h}else{&self.a};
        list.iter().find(|p|p.parent==parent&&p.part==part).ok_or_else(||"R14 split: role/piece is not declared".into())
    }

    fn audit(&self,base:&Shape)->Result<(),String> {
        for (planes,old,components,rows) in [(&self.a,base.a_plane_doms(),1,self.a_data_rows),(&self.h,base.h_plane_doms(),2,self.h_data_rows)] {
            let mut cursor=0;
            for p in planes {
                if p.offset!=cursor*self.n||old[p.parent]!=p.domain {return Err("R14 split: overlapping/foreign physical source".into());}
                cursor+=components*p.rows_per_component;
            }
            if cursor!=rows {return Err("R14 split: physical source row count differs".into());}
            for (parent,domain) in old.iter().enumerate() {
                let expected=if matches!(domain,Dom::D|Dom::F) {2}else{1};
                if planes.iter().filter(|p|p.parent==parent).count()!=expected {return Err("R14 split: dropped/duplicated logical role".into());}
            }
        }
        for h in [false,true] {
            let mut next=if h {self.h_data_rows}else{self.a_data_rows};
            for s in &self.slots {for &pair in if h {&s.h_pairs}else{&s.a_pairs} {
                if pair!=next {return Err("R14 split: mask pair is reused or skipped".into());}next+=2;
            }}
            if next+2!=if h {self.h_rows}else{self.a_rows} {return Err("R14 split: proximity pair not exclusive".into());}
        }
        if self.slots.len()!=base.n_slots()+8 {return Err("R14 split: slot inventory lost a logical relation".into());}
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use super::super::shape::{self,NormCalibration};
    fn calibration()->NormCalibration {NormCalibration{tn:9,cn_a:100,cn_m:100,ceps:1,sh_ao:7,sh_qkv:8,sh_s:6,sh_o:9,sh_g:8,sh_h:14,sh_z:6}}

    #[test]
    fn native_split_inventory_census() {
        for profile in [shape::R13_SHIELD_T128_H24,shape::R13_SHIELD_T128_H24_DD,shape::R13_SHIELD_T256_H24,shape::R13_SHIELD_T256_H24_DD] {
            for fe in [9,12,16] {
                let sh=Shape::accuracy_trained(profile,&calibration(),fe,20).unwrap();
                let old=Layout::for_shape(&sh).unwrap();let s=SplitLayout::new(&sh,[2048,1024],[8192,1024]).unwrap();
                let(a0,h0)=sh.claim_sites();let a1=s.slots.iter().map(|s|s.a_sites).sum::<usize>();let h1=s.slots.iter().map(|s|s.h_sites).sum::<usize>();
                assert_eq!(a1-a0.iter().sum::<usize>(),74);assert_eq!(h1-h0.iter().sum::<usize>(),25);
                assert_eq!((s.endpoint.data_rows,s.endpoint.external_rows,s.endpoint.internal_rows),(24,31,34));
                let before=(old.a_rows+old.h_rows)*old.n();let after=(s.a_rows+s.h_rows)*s.n;
                let byte_queries=lookups_at(&sh,old.ids(),Dom::D).len()*sh.tokens*3072
                    +lookups_at(&sh,old.ids(),Dom::F).len()*sh.tokens*9216
                    +old.lookup_doms().into_iter().filter(|d|!matches!(d,Dom::D|Dom::F)).map(|d|lookups_at(&sh,old.ids(),d).len()*sh.size(d)).sum::<usize>();
                eprintln!("R14_SPLIT_CENSUS {{\"base_profile\":{:?},\"f_e\":{},\"tokens\":{},\"dd\":{},\"n\":{},\"a_planes\":{},\"h_planes\":{},\"a_rows\":{},\"h_rows\":{},\"a_sites\":{},\"h_sites\":{},\"slots\":{},\"m_rows\":{},\"joint_external_rows\":{},\"joint_internal_rows\":{},\"a_h_words\":{},\"base_a_h_words\":{},\"byte_queries\":{},\"act_queries\":{},\"scope\":\"COUNTED native typed inventory and slot declaration only; polynomial/claim builders and new profile not wired\"}}",profile,fe,sh.tokens,sh.dd_cap>0,s.n,s.a.len(),s.h.len(),s.a_rows,s.h_rows,a1,h1,s.slots.len(),s.m_rows,s.endpoint.external_rows,s.endpoint.internal_rows,after,before,byte_queries,sh.tokens*9216);
            }
        }
    }

    #[test]
    fn split_inventory_refuses_missing_extent_and_short_h_piece() {
        let sh=Shape::accuracy_trained(shape::R13_SHIELD_T128_H24,&calibration(),9,20).unwrap();
        assert!(SplitLayout::new(&sh,[1024,1024],[8192,1024]).is_err());
        assert!(SplitLayout::new(&sh,[1024,2048],[8192,1024]).is_err());
        let mut short=sh.clone();short.log_cols=18;
        assert!(SplitLayout::new(&short,[2048,1024],[8192,1024]).unwrap_err().contains("H-bearing piece"));
        let s=SplitLayout::new(&sh,[2048,1024],[8192,1024]).unwrap();
        let ids=Ids::new(&sh).unwrap();let x=ids.at(A_X);
        assert!(s.plane(false,x,Part::Whole).is_err());
        let wide=s.plane(false,x,Part::Wide).unwrap();let narrow=s.plane(false,x,Part::Narrow).unwrap();
        assert_eq!(wide.log,narrow.log+1);assert_ne!(wide.offset,narrow.offset);
    }
}
