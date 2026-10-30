"""Prepare isolated R13 registry candidates; never mutate the build tree."""
from pathlib import Path

HERE = Path(__file__).resolve().parent
SRC = HERE.parent / "working-tree/hashline/src/private_block"

tables = (HERE / "accuracy_tables.red.rs").read_text()
tables = tables.replace(
    "// Failing-first adapter: the baseline registry still refuses the new member.\n"
    "pub(crate) fn silu_table_for(_registry:Registry,e_in:i32,e_out:i32,input_bits:u32) -> Result<Vec<i16>,String> {\n"
    "    silu_table(e_in,e_out,input_bits)\n}",
    """// The standard nine members retain their existing quantization exactly.
pub(crate) fn silu_table_for(registry: Registry, e_in: i32, e_out: i32, input_bits: u32) -> Result<Vec<i16>, String> {
    if input_bits != 12 || !registry.permits((e_in, e_out)) {
        return Err("R13 SiLU: int12 input and a member of the profile registry required".into());
    }
    if SILU_MEMBERS.contains(&(e_in, e_out)) {
        return silu_table(e_in, e_out, input_bits);
    }
    // Only the Shieldstral (0,-8) member reaches this path. No saturation is
    // allowed for this member; an out-of-range output is an error.
    (-2048..2048).map(|gate| {
        let x = gate as f64 / 16.0;
        let word = (256.0 * x / (1.0 + (-x).exp()) + 0.5).floor();
        if !word.is_finite() || !(-32767.0..=32767.0).contains(&word) {
            return Err("R13 Shieldstral SiLU: generated word exceeds signed16".into());
        }
        Ok(word as i16)
    }).collect()
}""",
)
assert "Failing-first adapter" not in tables
(HERE / "accuracy_tables.green.rs").write_text(tables)

groups = (SRC / "accuracy_groups.rs").read_text()
groups = groups.replace("use super::accuracy_tables::SILU_MEMBERS;", "use super::accuracy_tables::Registry;")
marker = "    if groups.is_empty()"
at = groups.index(marker)
groups = groups[:at] + """    group_folds_for(Registry::Standard, groups, ids, gate_multipliers, base_e_in, base_e_out, base_sh_g, base_sh_h)
}

pub(crate) fn group_folds_for(
    registry: Registry, groups: &[Group], ids: &[usize], gate_multipliers: &[u64],
    base_e_in: i32, base_e_out: i32, base_sh_g: u32, base_sh_h: u32,
) -> Result<GroupFolds, String> {
""" + groups[at:]
groups = groups.replace("!SILU_MEMBERS.contains(&(base_e_in, base_e_out))", "!registry.permits((base_e_in, base_e_out))")
groups = groups.replace("!SILU_MEMBERS.contains(&(g.e_in, g.e_out))", "!registry.permits((g.e_in, g.e_out))")
groups = groups.replace("let product_shift = *product_shifts.iter().max().unwrap();", "// A zero direct shift is represented exactly by multiplier 2 / 2.\n    let product_shift = (*product_shifts.iter().max().unwrap()).max(1);")
groups = groups.replace("!(1..=12).contains(&s)", "!registry.product_shifts().contains(&s)")
(HERE / "accuracy_groups.green.rs").write_text(groups)

aligned = (SRC / "accuracy_aligned.rs").read_text()
aligned = aligned.replace("use super::accuracy_precision::Stack;", "use super::accuracy_precision::Stack;\nuse super::accuracy_tables::Registry;")
at = aligned.index("    use super::accuracy_groups::{group_folds, Folded};")
aligned = aligned[:at] + """    derive_aligned_for(Registry::Standard, stack, groups, ids, gate, base_in, base_out, base_sh_g, base_sh_h)
}

pub(crate) fn derive_aligned_for(
    registry: Registry, stack: Stack, groups: &[Group], ids: &[usize], gate: &[u64],
    base_in: i32, base_out: i32, base_sh_g: u32, base_sh_h: u32,
) -> Result<Aligned, String> {
""" + aligned[at:]
aligned = aligned.replace("{group_folds, Folded}", "{group_folds_for, Folded}")
aligned = aligned.replace("use super::accuracy_tables::silu_table;", "use super::accuracy_tables::silu_table_for;")
aligned = aligned.replace("group_folds(groups,", "group_folds_for(registry, groups,")
aligned = aligned.replace("!(4..=15).contains(&exponent)", "!registry.scaled_exponents().contains(&exponent)")
aligned = aligned.replace("silu_table(group.e_in, group.e_out, 12)?", "silu_table_for(registry, group.e_in, group.e_out, 12)?")
aligned = aligned.replace("filter(|v| v.abs() <= 32767 * (1 << 15))", "filter(|v| v.abs() <= registry.scaled_abs())")
aligned = aligned.replace("output exceeds signed31", "output exceeds the profile signed-word class")
aligned = aligned.replace('include_str!("r13_vectors/', 'include_str!("../working-tree/hashline/src/private_block/r13_vectors/')
(HERE / "accuracy_aligned.green.rs").write_text(aligned)

(HERE / "green_harness.rs").write_text('''#![allow(dead_code)]
#[path="../working-tree/hashline/src/private_block/accuracy.rs"] mod accuracy;
#[path="../working-tree/hashline/src/private_block/accuracy_precision.rs"] mod accuracy_precision;
#[path="accuracy_tables.green.rs"] mod accuracy_tables;
#[path="accuracy_groups.green.rs"] mod accuracy_groups;
#[path="accuracy_aligned.green.rs"] mod accuracy_aligned;

#[test]
fn both_shieldstral_stacks_match_2016_independent_fraction_vectors() {
    use accuracy_precision::Stack;
    use accuracy_tables::{Registry, SILU_MEMBERS};
    use accuracy_groups::Group;
    let members:Vec<_>=SILU_MEMBERS.into_iter().chain([(0,-8)]).collect();
    let mut count=0;
    for row in include_str!("../shieldstral_product_vectors.tsv").lines() {
        if row.starts_with("stack") {continue}
        let v:Vec<_>=row.split('\\t').collect();
        let stack=match v[0] {"low"=>Stack::Low,"low-h24"=>Stack::LowH24,other=>panic!("{other}")};
        let base_h:u32=v[1].parse().unwrap();
        let delta:i32=v[2].parse().unwrap();
        let base=if delta>=0 {(-5,-13)} else {(0,-8)};
        let member=*members.iter().find(|m| m.1==base.1+delta).unwrap();
        let aligned=accuracy_aligned::derive_aligned_for(Registry::Shieldstral,stack,&[Group{e_in:member.0,e_out:member.1}],&[0],&[1],base.0,base.1,8,base_h).unwrap();
        let exponent:u32=v[3].parse().unwrap();
        assert_eq!(aligned.folds.product.multipliers[0],1<<exponent);
        let a:i128=v[4].parse().unwrap(); let up:i128=v[5].parse().unwrap(); let expected:i64=v[6].parse().unwrap();
        let rounded=accuracy::requant(a*up,1<<exponent,aligned.folds.product.shift).unwrap();
        assert_eq!(rounded.word,expected,"{row}");
        count+=1;
    }
    assert_eq!(count,2016);
}

#[test]
fn shieldstral_actual_l25_four_groups_fit_and_standard_refuses_them() {
    use accuracy_groups::Group;
    use accuracy_tables::Registry;
    let groups=[Group{e_in:-3,e_out:-11},Group{e_in:-2,e_out:-11},Group{e_in:-1,e_out:-9},Group{e_in:0,e_out:-8}];
    let a=accuracy_aligned::derive_aligned_for(Registry::Shieldstral,accuracy_precision::Stack::LowH24,&groups,&[0,1,2,3],&[1;4],-1,-9,8,15).unwrap();
    assert_eq!(a.tables.len()*4096,16384);
    assert_eq!(a.folds.product.multipliers,vec![128,128,512,1024]);
    assert!(accuracy_aligned::derive_aligned(accuracy_precision::Stack::LowH24,&groups,&[0,1,2,3],&[1;4],-1,-9,8,15).is_err());
}

#[test]
fn zero_direct_shift_preserves_negative_values_exactly() {
    use accuracy_tables::Registry;
    let g=[accuracy_groups::Group{e_in:0,e_out:-8}];
    let folded=accuracy_groups::group_folds_for(Registry::Shieldstral,&g,&[0],&[1],-5,-13,8,13).unwrap();
    assert_eq!(folded.product.shift,1);
    assert_eq!(folded.product.multipliers,vec![2]);
    for n in [-100000i128,-3,-1,0,1,3,100000] {assert_eq!(accuracy::requant(n,2,1).unwrap().word,n as i64);}
}
''')
