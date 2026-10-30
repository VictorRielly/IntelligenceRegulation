"""Count current native short-content limits against the complete A1 inputs."""
from collections import defaultdict
import hashlib
import json
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    policies_path=HERE/'category_policy_candidates.json'
    inputs_path=HERE/'evaluation_inputs/input.json'
    policies=json.loads(policies_path.read_text());inputs=json.loads(inputs_path.read_text())
    assert sha(inputs_path)==policies['evaluation_input_sha256']
    assert len(inputs['rows'])==4872
    groups=defaultdict(list)
    for row in inputs['rows']:groups[(row['template'],row['dataset'])].append(row['content_tokens'])
    counts=[]
    for (template,dataset),lengths in sorted(groups.items()):
        policy=policies['policies'][template]
        for tokens,size in policy['content_tokens_by_T'].items():
            short=sum(n<size for n in lengths);exact=sum(n==size for n in lengths)
            counts.append({'template':template,'dataset':dataset,'T':int(tokens),'chunk_size':size,
                'items':len(lengths),'short_items_refused_by_current_native_split':short,
                'short_fraction':short/len(lengths),'exact_single_chunk_items':exact,
                'longer_items_requiring_split':sum(n>size for n in lengths)})
    native=ROOT/'ops/zkp-mvp/token-io-r12b/hashline/src/private_block/token_io/classify.rs'
    assert 'short content is not built' in native.read_text()
    result={'schema':'zk60-category-chunk-coverage/1',
        'scope':'COUNTED input lengths only; not a proof run or policy/profile registration. Counts are unweighted.',
        'required_work':'Native short-content support is required; no padding or truncation workaround is introduced.',
        'policies_sha256':sha(policies_path),'inputs_sha256':sha(inputs_path),
        'native_chunk_source_sha256':sha(native),'tool_sha256':sha(Path(__file__)),'counts':counts}
    (HERE/'category_chunk_coverage.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'rows_checked':4872,'groups':len(groups),
        'T128_short_fraction_range':[min(x['short_fraction'] for x in counts if x['T']==128),max(x['short_fraction'] for x in counts if x['T']==128)],
        'T256_short_fraction_range':[min(x['short_fraction'] for x in counts if x['T']==256),max(x['short_fraction'] for x in counts if x['T']==256)]}))

if __name__=='__main__':main()
