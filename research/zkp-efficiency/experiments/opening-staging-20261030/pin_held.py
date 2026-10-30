import difflib,hashlib,json,pathlib
D=pathlib.Path(__file__).resolve().parent
P=D.parents[3]
H=P/'results/zk60_1b_native_20261017/r14/actual-working-tree'
def extract(s,needle):
 a=s.index(needle);p=s.index('{',a);i=p+1;depth=1
 while depth:depth+=(s[i]=='{')-(s[i]=='}');i+=1
 return s[a:i]+'\n'
def sha(b):return hashlib.sha256(b).hexdigest()
pins=json.loads((D/'source-pins.json').read_text());comp=[]
names=['zkp-core/src/field.rs','zkp-core/src/pcs.rs','zkp-core/src/pcs/backend.rs','hashline/src/gpu/cuda.rs','hashline/src/gpu/kernels.cu']
for name in names:
 p=H/name;b=p.read_bytes();dest=D/'held-source'/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(b)
 rec={'path':str(p),'snapshot':str(dest.relative_to(D)),'bytes':len(b),'sha256':sha(b)}
 before=next((x for x in pins if x['path']==str(p)),None)
 if before:assert before==rec
 else:pins.append(rec)
for file,needle in [('zkp-core/src/pcs.rs','fn fold_rows_host('),('zkp-core/src/pcs.rs','fn fold_rows_multi_zk<'),('hashline/src/gpu/cuda.rs','pub fn dev_fold_rows('),('hashline/src/gpu/kernels.cu','extern "C" __global__ void k_fold_rows(')]:
 a=extract((P/file).read_text(),needle);b=extract((H/file).read_text(),needle)
 comp.append({'file':file,'symbol':needle,'bodies_identical':a==b,'root_body_sha256':sha(a.encode()),'held_body_sha256':sha(b.encode())})
comp.append({'file':'zkp-core/src/field.rs','whole_file_identical':(P/'zkp-core/src/field.rs').read_bytes()==(H/'zkp-core/src/field.rs').read_bytes()})
(D/'held-seam-comparison.json').write_text(json.dumps(comp,indent=2)+'\n');(D/'source-pins.json').write_text(json.dumps(pins,indent=2)+'\n')
patch=[]
for file in ['zkp-core/src/pcs/backend.rs','zkp-core/src/pcs.rs']:
 old=(H/file).read_text();new=old
 if file.endswith('backend.rs'):
  line='    fn fold_rows(&self, rhos: &[Vec<Fp2>]) -> Result<Vec<Vec<Fp2>>, String>;\n'
  hook='''    /// Fold one opening without changing rho order. Default keeps max-four calls.
    /// Overrides must retain opening-local scratch through every queued use,
    /// propagate errors, and preserve exact field values and fresh proof state.
    fn fold_rows_opening(&self, rhos: &[Vec<Fp2>]) -> Result<Vec<Vec<Fp2>>, String> {
        let mut out = Vec::with_capacity(rhos.len());
        for chunk in rhos.chunks(4) {
            out.extend(self.fold_rows(chunk)?);
        }
        Ok(out)
    }
'''
  assert old.count(line)==1;new=old.replace(line,line+hook)
  (D/'opening_trait.rs').write_text(extract(new,'pub trait EncodedStore: Sync'))
 else:
  body='''            let mut m = Vec::with_capacity(rhos.len());
            for chunk in rhos.chunks(4) {
                m.extend(dc.fold_rows(chunk).expect("pcs: external store row-combination"));
            }
            m'''
  start=old.index('fn fold_rows_multi_zk<');left=old[:start];right=old[start:];assert right.count(body)==1
  new=left+right.replace(body,'            dc.fold_rows_opening(rhos).expect("pcs: external store row-combination")',1)
 patch.extend(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='a/'+file,tofile='b/'+file))
(D/'opening-hook-review-only.patch').write_text(''.join(patch));print(json.dumps({'pins':len(pins),'seams_identical':all(x.get('bodies_identical',x.get('whole_file_identical')) for x in comp),'patch_applied':False}))
