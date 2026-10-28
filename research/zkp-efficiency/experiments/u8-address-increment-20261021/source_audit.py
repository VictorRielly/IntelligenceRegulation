import hashlib, json, pathlib, resource, time
ROOT=pathlib.Path(__file__).resolve().parent
t0=time.monotonic(); checks=0; pins=[]


def check(ok):
    global checks
    assert ok
    checks+=1


for pin in json.loads((ROOT/'source-manifest.json').read_text()):
    live=pathlib.Path(pin['path']).read_bytes(); saved=(ROOT/pin['snapshot']).read_bytes()
    check(hashlib.sha256(live).hexdigest()==pin['sha256'])
    check(live==saved);pins.append(pin['sha256'])

requirements={
 'protocol.rs': ['let u8_inv = u8_denominator_inverses(alpha, g_u8);',
                 'helper_pair_inverses_u8(&cols[2 * k], second',
                 'write_h(&mut h_data, lay.h_off[first + k], &col);',
                 'let alpha = tr.challenge_fp2();', 'absorb_root(tr, b"A"',
                 'tr.absorb(b"M", &mask_root);'],
 'argument.rs':['h.mul(d1).mul(d2).sub(d1.add(d2))', 'h.mul(d1).sub(Fp2::ONE)',
                'b.a(ids.at(A_MU8))?;', 'SC_TAB => {'],
 'layout.rs':['pub(crate) fn lookups_at(', 'v.push(scaled(ids.nr(ln - 1), norm_scale));'],
 'core-pcs.rs':['let pads = rng.fp_vec(rows * q);',
                'let salts: Vec<[u8; 32]> = (0..nn).map(|_| rng.bytes32()).collect();',
                'let encoded = encode_buffer::encode_rows(ntt, data_ref, n, &pads, q, &pows);',
                'let leaves = hash_columns_keyed(&encoded, rows, nn, tag.column_key());',
                'let mut coeffs = msg.to_vec();', 'ntt.inverse(&mut coeffs);', 'ntt.forward(out);']}
anchors=[]
for file, fragments in requirements.items():
    text=(ROOT/'source'/file).read_text()
    for fragment in fragments:
        check(fragment in text)
        changed=text.replace(fragment,'/* omitted obligation control */')
        check(fragment not in changed)
        anchors.append(dict(file=file,line=text[:text.index(fragment)].count('\n')+1,fragment=fragment))
protocol=(ROOT/'source/protocol.rs').read_text()
start=protocol.index('let mut a = pcs::commit_zk_owned_tagged')
check(start < protocol.index('tr.absorb(b"M", &mask_root);',start) < protocol.index('let alpha = tr.challenge_fp2();',start) < protocol.index('let u8_inv = u8_denominator_inverses(alpha, g_u8);',start))
(ROOT/'source-anchors.json').write_text(json.dumps(anchors,indent=2)+'\n')
result=dict(status='PASS_SOURCE_OBLIGATIONS_ONLY',checks=checks,live_copy_pins=len(pins),
            fragment_mutations=len(anchors),wall_seconds=time.monotonic()-t0,
            rss_kib=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            limits='Substring/source-order checks, not compiler/native protocol or security review')
(ROOT/'source-audit-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
