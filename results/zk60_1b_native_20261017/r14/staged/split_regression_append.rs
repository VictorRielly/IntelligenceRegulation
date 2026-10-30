
// Remaining R13 relation families exercised through the R14 physical layout.
// These hooks alter only the test prover's derived histogram/helper. The
// verifier's table support, native argument, global H sum, M and PCS stay live.
thread_local! {
    static TABLE_MOVE: Cell<Option<(usize,usize,usize)>> = const {Cell::new(None)};
}
pub(crate) fn table_move() -> Option<(usize,usize,usize)> {TABLE_MOVE.with(Cell::get)}
struct TableMoveScope;
impl TableMoveScope {
    fn new(which: usize,from: usize,to: usize) -> Self {
        TABLE_MOVE.with(|s|assert!(s.replace(Some((which,from,to))).is_none()));Self
    }
}
impl Drop for TableMoveScope {fn drop(&mut self){TABLE_MOVE.with(|s|s.set(None));}}

#[test]
#[ignore="separately guarded R14 limb/dictionary/table-support emitted receipts; explicit regression/DD"]
fn split_run_t128_relation_regression_receipt_from_env() {
    let name=std::env::var("HL_R14_REGRESSION").expect("explicit relation regression required");
    let dd=match std::env::var("HL_R14_DD").unwrap().as_str(){"0"=>false,"1"=>true,_=>panic!("DD0/1")};
    let(sh,blocks,_)=fixture(dd);let mut blk=blocks[0].clone();
    // The ACT support probe needs the registered group0 gate=0 row, whose
    // padded copy carries exactly the same three-coordinate tuple.
    if name=="table-act-support" {blk.feed_forward.wg_t.fill(0);}
    let mut w=witness::build_for_block(&sh,&blk,&input(&sh)).unwrap();
    let ids=Ids::new(&sh).unwrap();let low=ids.accuracy().unwrap();
    let mut moved=None;
    if name.starts_with("limb-") {
        let parts=name.split('-').collect::<Vec<_>>();assert_eq!(parts.len(),3);
        let(role,k)=match parts[1] {
            "y"=>(Limbs::Y,1),"ym"=>(Limbs::Ym,1),"q"=>(Limbs::Q,1),
            "k"=>(Limbs::K,1),"v"=>(Limbs::V,1),"o"=>(Limbs::O,1),
            "rao"=>(Limbs::Rao,2),"rs"=>(Limbs::Rs,2),"rg"=>(Limbs::Rg,2),
            "up"=>(Limbs::Up,1),"h"=>(Limbs::H,2),"rh"=>(Limbs::Rh,1),
            "rd"=>(Limbs::Rd,2),_=>panic!("unknown limb family"),
        };
        let parent=low.limb(role,k);let dom=ids.dom(parent);
        let index=match parts[2] {
            "wide"=>{assert!(matches!(dom,Dom::D|Dom::F));0},
            "narrow"=>match dom{Dom::D=>2048,Dom::F=>8192,_=>panic!("non-piece narrow limb")},
            "whole"=>{assert!(!matches!(dom,Dom::D|Dom::F));0},
            _=>panic!("unknown physical piece"),
        };
        let old=w.planes[parent][index];w.planes[parent][index]^=1;
        assert!((0..256).contains(&w.planes[parent][index]));
        eprintln!("R14_RELATION_MUTATION case={name} parent={parent} domain={dom:?} global_index={index} old={old} new={}",w.planes[parent][index]);
    } else if name=="dictionary-unused" {
        assert!(dd);let column=blk.attention().dd_e_column(sh.dd_cap).unwrap();
        let k=(0..sh.dd_cap).rev().find(|&k|column[k]==0 && w.planes[ids.mdd()][k]==0).expect("unused dictionary slot");
        assert_eq!(w.planes[ids.pdict()][k],0);w.planes[ids.pdict()][k]=1;
        w.planes[low.limb(Limbs::P,0)][k]=1;
    } else if name=="dictionary-counts" {
        assert!(dd);let from=(0..sh.dd_cap).find(|&k|w.planes[ids.mdd()][k]>0).unwrap();
        let to=sh.dd_cap-1;assert_ne!(from,to);
        let total=w.planes[ids.mdd()].iter().sum::<i64>();
        w.planes[ids.mdd()][from]-=1;w.planes[ids.mdd()][to]+=1;
        assert_eq!(w.planes[ids.mdd()].iter().sum::<i64>(),total);
    } else {
        let(which,from,to)=match name.as_str(){
            "table-byte-support"=>(0,0,256),"table-exp-support"=>(1,127,383),
            "table-act-support"=>(2,2048,blk.accuracy().unwrap().groups().len()*4096),
            _=>panic!("unknown R14 relation regression"),
        };
        moved=Some(TableMoveScope::new(which,from,to));
    }
    // A host lookup miss is a fixture failure, never a native-refusal pass.
    protocol::check_lookup_misses(&sh,&Layout::for_shape(&sh).unwrap(),&blk,&w).unwrap();
    emit(sh,blk,w,0,&name,false);
    drop(moved);
}
