from pathlib import Path

p=Path(__file__).resolve().parent
src=p.parent/"working-tree/hashline/src/private_block"
s=(src/"accuracy_public.rs").read_text()
marker="#[derive(Clone, Debug, PartialEq, Eq)]\npub(crate) struct Multipliers"
assert s.count(marker)==1;s=s.replace(marker,(p/"encoding_fn.rs").read_text()+marker)
s=s.replace('let mut out = b"zk60-low-public/v2\\0".to_vec();','let mut out = ENCODING_DOMAIN.to_vec();')
at=s.rfind("\n}");s=s[:at]+"\n"+(p/"encoding_tests.rs").read_text()+s[at:]
(p/"accuracy_public.candidate.rs").write_text(s)

s=(src/"accuracy_profile_tests.rs").read_text()
s+='''
pub(super) fn registered_shapes()->Vec<Shape> {
    shape::ACCURACY_PROFILES.iter().map(|s|Shape::accuracy_trained(s.profile,&calibration(s.width),if s.width<256 {12} else {9},20).unwrap()).collect()
}
'''
(p/"accuracy_profile_tests.candidate.rs").write_text(s)

for name in ("s24_tests.rs","s25_tests.rs","s33_tests.rs"):
    s=(src/name).read_text()
    if name=="s24_tests.rs":
        needle="    shapes.extend(super::trained_calib_tests::registered_trained_shapes());"
        assert s.count(needle)==1;s=s.replace(needle,needle+"\n    shapes.extend(super::accuracy_profile_tests::registered_shapes());")
    if name=="s33_tests.rs":
        needle="    built.extend(super::trained_calib_tests::registered_trained_shapes().iter().map(|sh| sh.profile.to_string()));"
        assert s.count(needle)==1;s=s.replace(needle,needle+"\n    built.extend(super::accuracy_profile_tests::registered_shapes().iter().map(|sh|sh.profile.to_string()));")
    if name=="s25_tests.rs":
        s=s.replace("31 + framed_i8(d * d)            // wq","31 + framed_i8(sh.q_pad() * d)            // wq")
        s=s.replace("+ framed_i8(d * d)           // wo","+ framed_i8(d * sh.q_pad())           // wo")
        marker="/// **D3 / D5, a schedule digest's input**"
        helper='''fn block_public_digest_input_lengths(sh:&Shape)->Vec<usize> {
    let base=block_public_digest_input_len(sh);
    if sh.accuracy_stack()==super::accuracy_precision::Stack::Legacy {return vec![base]}
    let geo=super::accuracy_public::Geometry{width:sh.width,query_width:sh.q_width(),kv_width:sh.kv_heads*sh.head_dim,hidden:sh.hidden};
    let registry=sh.accuracy_registry();let stack=sh.accuracy_stack();
    (1..=4).map(|groups| {
        // Independent transcription of the framing, not the production
        // helper's expression. Its inputs are all constructor-bounded.
        let prefix=19+4+registry.name().len()+4+stack.export_name().unwrap().len();
        let axes=7*8+2*(sh.q_width()+2*sh.kv_heads*sh.head_dim+2*sh.width+2*sh.hidden);
        let context=32+36+8;
        let members=8+groups*8;let ids=8+sh.hidden*8;let tables=groups*(8+8192);
        let encoded=prefix+context+axes+members+ids+tables;
        assert_eq!(encoded,super::accuracy_public::encoded_len(geo,registry,stack,groups).unwrap());
        base+12+8+encoded
    }).collect()
}

'''
        assert s.count(marker)==1;s=s.replace(marker,helper+marker)
        needle='    push("the block\'s public/weights digest (D2)".to_string(), "F_U", block_public_digest_input_len(sh));'
        assert s.count(needle)==1;s=s.replace(needle,'''    for (index,len) in block_public_digest_input_lengths(sh).into_iter().enumerate() {
        let label=if sh.accuracy_stack()==super::accuracy_precision::Stack::Legacy {"the block's public/weights digest (D2)".to_string()}
            else {format!("the block's public/weights digest (D2, R13 groups={})",index+1)};
        push(label,"F_U",len);
    }''')
        needle="    for sh in super::trained_calib_tests::registered_trained_shapes() {"
        assert s.count(needle)==1;s=s.replace(needle,"    for sh in super::trained_calib_tests::registered_trained_shapes().into_iter().chain(super::accuracy_profile_tests::registered_shapes()) {")
        needle="    all_shapes.extend(super::trained_calib_tests::registered_trained_shapes());"
        assert s.count(needle)==1;s=s.replace(needle,needle+"\n    all_shapes.extend(super::accuracy_profile_tests::registered_shapes());")
    (p/(name.replace(".rs",".candidate.rs"))).write_text(s)
print("prepared encoding and full-profile hash-class candidates; no working source edits")
