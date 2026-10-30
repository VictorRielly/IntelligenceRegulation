"""Stage a strict actual-L25 native gate from the authenticated T128 prefix."""
import hashlib,json
from pathlib import Path
HERE=Path(__file__).resolve().parent
oracle=json.loads((HERE/'l25-causal-prefix/ORACLE.json').read_text());assert oracle['tokens']==128 and oracle['layer']==25
hashes={r['site']:r['sha256'] for r in oracle['trace_sites']}
roles=[('input','A_X'),('y','A_Y'),('q','A_Q8'),('k','A_K8'),('v','A_V8'),('qr','A_QR8'),('kr','A_KR8'),('s','A_S8'),('p','A_P'),('o','A_O8'),('ao','A_AO'),('x1','A_X1'),('nm','A_YM'),('gate','A_G8'),('a_scaled','A_A16'),('up','A_U16'),('h','A_H16'),('z','A_Z16'),('x2','A_X2')]
text=(HERE/'staged/split_actual_tests.template').read_text()
text=text.replace('@@ORACLE_ENTRIES@@','\n'.join(f'    ("{name}",{role},"{hashes[name]}"),' for name,role in roles))
text=text.replace('04102cce64dea0cd45dee5caa62095da1cf33fcaabd5647554202b564e6e7e57','2ba468f98085caf1136f27cf66220f93d8e316acb8dbae7e98f9eb68347f05a0')
line='    assert_eq!(hex(&sha256(&std::fs::read(root.join("PUBLIC_ORACLE.json")).unwrap())),"9fe10a9c257bd18baf1dd00d752ddfa4e46ef0db914027fcc715d26f2d8e59b2");\n'
assert text.count(line)==1;text=text.replace(line,'')
assert text.count('ex.run_constants(&[0])')==1 and text.count('ex.load_layer(&seed,&c,0,false)')==1
text=text.replace('ex.run_constants(&[0])','ex.run_constants(&[25])').replace('ex.load_layer(&seed,&c,0,false)','ex.load_layer(&seed,&c,25,false)')
start=text.index('    let mut input=vec![0i16;sh.tokens*sh.width];')
end=text.index('    let w=witness::build_for_block',start)
text=text[:start]+'''    let file=std::path::PathBuf::from(std::env::var("HL_R14_L25_INPUT").expect("retained reviewer prefix input"));
    let bytes=std::fs::read(file).unwrap();assert_eq!(bytes.len(),128*3072*2);
    assert_eq!(hex(&sha256(&bytes)),"'''+oracle['input_sha256']+'''");
    let input=bytes.chunks_exact(2).map(|b|i16::from_le_bytes([b[0],b[1]])).collect::<Vec<_>>();
'''+text[end:]
text=text.replace('split_actual_s2_t128','split_actual_l25_t128').replace('[201;32]','[225;32]')
text=text.replace('L00','L25').replace('public synthetic input','reviewer residual causal prefix')
text=text.replace('R14_ACTUAL_','R14_ACTUAL_L25_').replace('R14-actual-S2-L25-public-input/1','R14-actual-S2-L25-reviewer-prefix/1')
(HERE/'staged/split_l25_tests.rs').write_text(text)
print('Staged actualL25/T128 strict19site/proof/fresh/corrupt tests; uncompiled')
