from pathlib import Path
import difflib,hashlib,json
e=Path(__file__).resolve().parent
pins=json.loads((e/'native-pins.json').read_text())
pin=next(p for p in pins if p['path'].endswith('/witness.rs'))
base=Path(pin['snapshot']).read_text()
snippet=(e/'i8_projection.rs').read_text()
anchor='/// half-split RoPE over `heads` heads per row'
assert base.count(anchor)==1
candidate=base.replace(anchor,snippet+'\n'+anchor)
calls=[
 ('matmul(&g, &y, g.d_pad, &public.wq, g.d_pad, g.d_pad, g.d_pad, dl)','matmul_i8_projection(&g, &y, g.d_pad, &public.wq, g.d_pad, g.d_pad, g.d_pad, dl, false)'),
 ('matmul(&g, &y, g.d_pad, &public.wk, g.d_pad, g.kvw, g.kvw, kvl)','matmul_i8_projection(&g, &y, g.d_pad, &public.wk, g.d_pad, g.kvw, g.kvw, kvl, false)'),
 ('matmul(&g, &y, g.d_pad, &public.wv, g.d_pad, g.kvw, g.kvw, kvl)','matmul_i8_projection(&g, &y, g.d_pad, &public.wv, g.d_pad, g.kvw, g.kvw, kvl, false)'),
 ('matmul(&g, &o8, g.d_pad, &public.wo, g.d_pad, g.d_pad, g.d_pad, dl)','matmul_i8_projection(&g, &o8, g.d_pad, &public.wo, g.d_pad, g.d_pad, g.d_pad, dl, false)'),
 ('matmul_in_out(&g, &nm, g.d_pad, &ff.wg_t, g.d_pad, g.f_pad, g.f_pad, fl)','matmul_i8_projection(&g, &nm, g.d_pad, &ff.wg_t, g.d_pad, g.f_pad, g.f_pad, fl, true)'),
 ('matmul_in_out(&g, &nm, g.d_pad, &ff.wu_t, g.d_pad, g.f_pad, g.f_pad, fl)','matmul_i8_projection(&g, &nm, g.d_pad, &ff.wu_t, g.d_pad, g.f_pad, g.f_pad, fl, true)'),
]
for old,new in calls:
 assert candidate.count(old)==1,old
 candidate=candidate.replace(old,new)
out=e/'candidate';out.mkdir(exist_ok=True)
(out/'witness.rs').write_text(candidate)
(e/'i8-projection-candidate.patch').write_text(''.join(difflib.unified_diff(base.splitlines(True),candidate.splitlines(True),fromfile='a/hashline/src/private_block/witness.rs',tofile='b/hashline/src/private_block/witness.rs')))
recovered=candidate.replace(snippet+'\n','')
for old,new in calls:recovered=recovered.replace(new,old)
assert recovered==base
assert 'quantize(&matmul_in_out(&g, &h16,' in candidate
(e/'candidate-metadata.json').write_text(json.dumps({'source_pin':pin,'candidate_sha256':hashlib.sha256(candidate.encode()).hexdigest(),'call_replacements':calls,'added_helper_sha256':hashlib.sha256(snippet.encode()).hexdigest(),'scope':'source reconstruction only; no Rust compile/native witness/refusal/transcript/bytes/privacy gates'},indent=2)+'\n')
print('PASS: six source calls replaced; down/quantize order unchanged; exact inverse reconstruction')
