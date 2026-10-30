"""Recreate exact extracted helpers, sequential adapters and unapplied diff."""
from pathlib import Path
import difflib
H=Path(__file__).resolve().parent
s=(H/'native/zkp-core__src__pcs__encode_buffer.rs').read_text()
a=s.index("fn initialize_row<'a>(");b=s.index('\n#[cfg(test)]',a)
(H/'baseline_row.rs').write_text(s[a:b].strip().replace('fn initialize_row','fn baseline_row',1)+'\n')
c=(H/'candidate_row.rs').read_text();c=c[c.index("fn candidate_row<'a>("):].replace('fn candidate_row','fn initialize_row',1)
new=s[:a]+c+'\n'+s[b:]
new=new.replace('//! R2a: initialize each encoded row once, directly in its final allocation.\n//! No `Fp` reference is formed until every element of that row was written.',
'//! Encode directly in the final allocation, using its prefix as coefficient scratch.\n//! An `Fp` slice spans only elements that have already been initialized.')
(H/'encode_buffer.candidate.rs').write_text(new)
(H/'initialize-in-output.patch').write_text(''.join(difflib.unified_diff(s.splitlines(True),new.splitlines(True),fromfile='a/zkp-core/src/pcs/encode_buffer.rs',tofile='b/zkp-core/src/pcs/encode_buffer.rs')))
for text,name in [(s,'baseline_serial.rs'),(new,'candidate_serial.rs')]:
 assert text.count('use rayon::prelude::*;\n')==1 and text.count('.par_chunks_mut(nn)')==1
 (H/name).write_text(text.replace('use rayon::prelude::*;\n','').replace('.par_chunks_mut(nn)','.chunks_mut(nn)'))
print('Extracted pinned baseline; built sequential adapters and review-only patch.')
