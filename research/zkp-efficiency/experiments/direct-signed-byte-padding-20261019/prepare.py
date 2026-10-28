"""Snapshot read-only native/evidence pins; generate an UNBUILT review patch."""
import difflib
import hashlib
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
PRIOR=HERE.parent/'public-constructor-transfer-20261019'
(HERE/'native').mkdir(exist_ok=True)
pins=json.loads((PRIOR/'source-pins.json').read_text())
for p in pins:
    data=Path(p['source']).read_bytes()
    assert hashlib.sha256(data).hexdigest()==p['sha256'],p['source']
    assert (PRIOR/p['snapshot']).read_bytes()==data
    (HERE/p['snapshot']).write_bytes(data)
(HERE/'source-pins.json').write_text(json.dumps(pins,indent=2)+'\n')

path=Path('hashline/src/private_block/trained_block.rs')
native=HERE/'native/hashline__src__private_block__trained_block.rs'
old=native.read_text()
new=old
for name in ['wq','wk','wv','wo','ga','gm','wg','wu','wd']:
    needle=f'pad_matrix(&{name}.i8s(),'
    assert new.count(needle)==1
    new=new.replace(needle,f'pad_matrix_bytes(&{name}.bytes,')
old_method='    fn i8s(&self) -> Vec<i8> {\n        self.bytes.iter().map(|b| *b as i8).collect()\n    }\n'
assert new.count(old_method)==1
new=new.replace(old_method,'')
sig='fn pad_matrix(w: &[i8],'
assert new.count(sig)==1
new=new.replace(sig,'fn pad_matrix_bytes(w: &[u8],')
copy='            row[..ti].copy_from_slice(src);'
assert new.count(copy)==1
new=new.replace(copy,'            // The loader already checked dtype, shape and exact byte length.\n            // Cast each source byte at its destination; no complete decode Vec.\n            for (dst, value) in row[..ti].iter_mut().zip(src.iter()) {\n                *dst = *value as i8;\n            }')
scatter='                row[inner[i]] = *v;'
assert new.count(scatter)==1
new=new.replace(scatter,'                row[inner[i]] = *v as i8;')
assert '.i8s()' not in new
assert new.count('pad_matrix_bytes(')==10
(HERE/'candidate-trained_block.rs').write_text(new)
patch=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='a/'+str(path),tofile='b/'+str(path)))
(HERE/'review-only-direct-signed-byte-padding.patch').write_text(patch)

prior=json.loads((PRIOR/'payload-ledger.json').read_text())
rows=[]
for oldrow in prior['rows']:
    row=oldrow.copy()
    row['pad_phase_bytes']-=prior['max_decode_temporary_bytes']
    row['loader_payload_envelope_bytes']=max(row['pad_phase_bytes'],row['constructor_phase_bytes'],row['record_phase_bytes'])
    row['full_envelope_saving_bytes']=oldrow['loader_payload_envelope_bytes']-row['loader_payload_envelope_bytes']
    row['current_next_with_pins_payload_envelope_bytes']=(row['pins']+1)*prior['public_payload_bytes']+row['loader_payload_envelope_bytes']
    row['envelope_gib']=row['current_next_with_pins_payload_envelope_bytes']/2**30
    rows.append(row)
ledger=dict(removed_decode_allocations_per_load=9,removed_decoded_bytes_per_load=218112000,
            largest_removed_decode_buffer_bytes=58720256,
            retained_raw11_bytes=prior['raw11_bytes'],retained_padded_i8_bytes=prior['padded_i8_bytes'],
            rows=rows,exclusions=prior['exclusions'],
            scope='Allocation-free public-only conservative phase envelopes inherited from cycle0086, full sealing load. Not actual RSS/VRAM, hardware fit, native allocation or elapsed time. Largest decode temporary subtraction reduces pad envelope only; later record peak unchanged.')
(HERE/'payload-ledger.json').write_text(json.dumps(ledger,indent=2)+'\n')
(HERE/'run_bounded.py').write_bytes((PRIOR/'run_bounded.py').read_bytes())
print(json.dumps(dict(status='PASS',source_pins=len(pins),r8_manifest_matches=sum(x['r8_manifest_match'] is True for x in pins),patch_lines=len(patch.splitlines()),decode_allocations=9,removed_decode_bytes=218112000,peak_saving_bytes=[r['full_envelope_saving_bytes'] for r in rows])))
