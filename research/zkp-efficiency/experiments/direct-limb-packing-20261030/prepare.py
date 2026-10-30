import difflib, hashlib, json, os, pathlib, platform
D=pathlib.Path(__file__).resolve().parent
P=pathlib.Path('/home/victor/IntelligenceRegulation')
pins=[]
for rel in ['zkp-core/src/field.rs','zkp-core/src/pcs.rs','hashline/src/gpu/cuda.rs','hashline/src/gpu/kernels.cu']:
    p=P/rel; b=p.read_bytes(); dest=D/'native'/rel
    dest.parent.mkdir(parents=True,exist_ok=True); dest.write_bytes(b)
    pins.append(dict(path=str(p),snapshot=str(dest.relative_to(D)),sha256=hashlib.sha256(b).hexdigest()))
(D/'field.rs').write_bytes((P/'zkp-core/src/field.rs').read_bytes())
s=(P/'zkp-core/src/pcs.rs').read_text(); a=s.index('fn fold_rows_host('); z=s.index('\n}',a)+2
(D/'native_host.rs').write_text(s[a:z].replace('.into_par_iter()', '.into_iter()')+'\n')
s=(P/'hashline/src/gpu/cuda.rs').read_text(); a=s.index('fn as_u64s_f2('); z=s.index('\n}',a)+2
helper=s[a:z]
a=s.index('    let mut flat: Vec<u64> = Vec::with_capacity(k * rows * 2);',s.index('pub fn dev_fold_rows('))
z=s.index('    let d_rho =',a)
body=s[a:z]
before='fn pack_native(rhos: &[Vec<Fp2>], rows: usize) -> Vec<u64> {\n    let k = rhos.len();\n    assert!(k >= 1 && k <= 4, "dev_fold_rows: {k} weight vectors (max 4)");\n'+body+'    flat\n}\n'
after=before.replace('fn pack_native(', 'fn pack_direct(').replace('        flat.extend(as_u64s_f2(rho));', '        for x in rho {\n            flat.push(x.c0.0);\n            flat.push(x.c1.0);\n        }')
assert before!=after
(D/'native_pack.rs').write_text(helper+'\n\n'+before+'\n'+after)
patch=list(difflib.unified_diff(s.splitlines(True),s.replace('        flat.extend(as_u64s_f2(rho));', '        for x in rho {\n            flat.push(x.c0.0);\n            flat.push(x.c1.0);\n        }',1).splitlines(True),fromfile='a/hashline/src/gpu/cuda.rs',tofile='b/hashline/src/gpu/cuda.rs'))
(D/'direct-pack-review-only.patch').write_text(''.join(patch))
(D/'source-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
cpu=next((v.split(':',1)[1].strip() for v in pathlib.Path('/proc/cpuinfo').read_text().splitlines() if v.startswith('model name')),'unknown')
(D/'hardware.json').write_text(json.dumps(dict(cpu=cpu,affinity=sorted(os.sched_getaffinity(0)),platform=platform.platform(),gpu_used=False,device_count=0),indent=2)+'\n')
print(json.dumps(dict(status='PASS',pins=len(pins),native_pack_extracted=True,patch_applied=False)))
