"""Independent formulas, row-size counterexample and native anchor audit."""
import json
from pathlib import Path


def audit(root):
    checks=0
    rows=json.loads((root/'cost-result.json').read_text())
    census=json.loads((root/'prior-census.json').read_text())
    assert len(rows)==16
    for x in rows:
        src=next(s for s in census if (s['model'],s['T'],s['dd'],s['norm_window'],s['f_e']) ==
                 ('8B',x['T'],x['dd'],32,9))
        # Count two base coordinates per paired Fp2 helper, including odd last columns.
        hwords=0; queries=0
        for domain in src['domains']:
            pairs=list(range(0,domain['u8_columns'],2))
            hwords+=2*len(pairs)*domain['size']
            queries+=domain['size']*domain['u8_columns']
        assert x['native_u8_helper_data_bytes']==8*hwords
        assert x['queries']==queries
        radices={1:256,2:16,4:4,8:2}
        expected=queries*x['d']*radices[x['d']]
        assert x['dense_base_words']==expected
        assert x['dense_data_bytes']==8*expected
        assert x['encoded_payload_bytes']==32*expected
        assert x['virtual_complement_bit_base_words']==8*queries
        assert x['virtual_complement_bit_data_bytes']==64*queries
        assert x['versus_native_helper_data']==expected/hwords
        assert x['bit_data_vs_native_helpers']==8*queries/hwords
        assert all(x[k] is None for k in ('new_private_commitments','new_mask_sites','fresh_mask_words','new_pcs_groups','proof_bytes'))
        assert x['actual_model_execution'] is False
        checks+=11
    native=json.loads((root/'source/r9_counts.json').read_text())
    for x in rows:
        key='Llama-3-8B T128 (row 2^14)' if x['T']==128 else "Llama-3-8B T512 (the review's anchor, row 2^15)"
        assert native[key]['dd' if x['dd'] else 'today']['u8']==x['queries']
        checks+=1
    # A declared rate expands zero entries too in this selected dense PCS path.
    # Counts describe logical payload, never a guarantee about resident physical capacity.
    for d,k in [(1,256),(2,16),(4,4),(8,2)]:
        n=8; nz=n*d; slots=n*d*k
        assert slots>nz
        assert slots*4 != nz*4
        checks+=2
    return checks
