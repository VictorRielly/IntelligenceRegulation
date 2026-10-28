"""Independent exponent/basis audit, native wrapping reader, source extraction pins."""
from pathlib import Path
import hashlib,json,random,resource,subprocess,time
from fp2 import E,P,Attempt,OrderedLookup
from tiled_fp2 import execute
import reference as R
H=Path(__file__).resolve().parent;t0=time.monotonic();rng=random.Random(20261020109)
checks=0;mutations=0;controls=[]
def check(x):
    global checks
    assert x;checks+=1
def control(name,x):check(x);controls.append(name)
def rnd():return E(rng.randrange(P),rng.randrange(P))
def pair(x):return tuple(x.pair())
def flat(x):return '%d %d'%(x.a,x.b)
def extract(s,name):
    start=s.index('fn '+name+'(');b=s.index('{',start);i=b+1;level=1
    while level:level+=(s[i]=='{')-(s[i]=='}');i+=1
    return s[start:i]

pins=json.loads((H/'source-pins.json').read_text())
for r in pins:
    data=Path(r['path']).read_bytes();check(hashlib.sha256(data).hexdigest()==r['sha256'])
    check(data==(H/r['snapshot']).read_bytes())
proto=(H/'source/protocol.rs').read_text();helpers=(H/'native_helpers.rs').read_text()
for name in ['u8_denominator_inverses','helper_one']:
    check(extract(proto,name)==extract(helpers,name))
for fragment in ['a.wrapping_add(c.wrapping_mul(wit.planes[*p][x]))',
    'let inv = inverses(tv.iter().map(|t| alpha.sub(*t)).collect())?;',
    'inv.iter().zip(m.iter()).map(|(x, c)| x.mul_base(Fp::new(*c)))']:
    check(fragment in proto)
    damaged=proto.replace(fragment,'omitted',1);check(fragment not in damaged);mutations+=1

# Independent inversion uses exponent p²-2, versus the candidate norm/base inverse.
for _ in range(96):
    x=rnd();check(pair(x.inv())==R.inv(pair(x)))
edges=[0,1,P-1,P-2,2**32-1,2**32,2**63,2**64-1]
for x in edges:
    for y in edges:
        a,b=E(x,y),E(y,x);check(pair(a*b)==R.mul(pair(a),pair(b)))

# Re-evaluate the saved original leaf fixtures without the tiled implementation.
fixtures=json.loads((H/'fixtures.json').read_text())
for f in fixtures:
    a,g=tuple(f['alpha']),tuple(f['g'])
    leaves=[((1,0),R.sub(a,R.add((v,0),g))) for v in f['values']]
    expected=R.direct(R.tree(leaves)[f['d']],[tuple(x) for x in f['point']],
        [tuple(x) for x in f['challenges']],tuple(f['lambda']))
    check(json.loads(json.dumps(expected))==[f['rows'],f['terminal'],f['final']])

# Exact syntactic native Lk families: byte, scale, sym plus general multi-term
# and wrapping controls. Original model weights/activations are never accessed.
attempt=Attempt(E(1009,97),E(31,17));n=32
planes=[tuple(rng.randrange(256) for _ in range(n)),
        tuple(rng.randrange(-127,128) for _ in range(n)),
        tuple(rng.randrange(128) for _ in range(n))]
descriptors=[(0,((0,1),)),(127,((1,1),)),(127,((1,-1),)),(0,((2,2),)),(7,((0,1),(2,-2)))]
lines=[];want=[];readers=[]
for cst,terms in descriptors:
    reader=OrderedLookup(attempt,planes,terms,cst);readers.append(reader)
    for i in range(n):
        # Independent modulo-word expression, then signed reinterpretation.
        word=(cst+sum(c*planes[p][i] for p,c in terms))%(1<<64)
        value=word if word<(1<<63) else word-(1<<64)
        check(reader.value(i)==value)
        lines.append(' '.join(['W',flat(attempt.alpha),flat(attempt.g),str(cst),str(len(terms))]+[str(z) for p,c in terms for z in [c,planes[p][i]]]))
        want.append((value,pair(attempt.helper(value))))
# Overflow is dishonest input arithmetic. It must still match the old reader;
# this is not a relaxation of native range/soundness requirements.
for cst,coef,word in [(127,1,(1<<63)-1),(0,-1,-(1<<63)),(17,256,(1<<63)-1),(-(1<<63),-1,1)]:
    reader=OrderedLookup(attempt,[(word,)],[(0,coef)],cst)
    v=reader.value(0)
    control('wrapping_differs_from_unbounded_'+str(len(controls)),E(v)!=E(cst+coef*word))
    lines.append(' '.join(['W',flat(attempt.alpha),flat(attempt.g),str(cst),'1',str(coef),str(word)]));want.append((v,pair(attempt.helper(v))))
native=subprocess.run([str(H/'oracle')],input='\n'.join(lines)+'\n',text=True,capture_output=True,timeout=10,check=True)
(H/'reader-native-input.txt').write_text('\n'.join(lines)+'\n');(H/'reader-native-output.txt').write_text(native.stdout)
check(len(native.stdout.splitlines())==len(want))
for line,(v,helper) in zip(native.stdout.splitlines(),want):
    tok=line.split();check(tok[:3]==['W',str(v),'OK']);check(tuple(map(int,tok[3:]))==helper)

reader_cases=0
for reader in readers:
    original=[(pair(x),pair(y)) for x,y in (reader.read(i) for i in range(n))]
    point=[rnd() for _ in range(4)];ch=[rnd() for _ in range(4)];lam=rnd()
    expect=R.direct(original,list(map(pair,point)),list(map(pair,ch)),pair(lam))
    for q in range(5):
        got=execute(reader.read,n,5,point,ch,q,lam,P)
        check(([[pair(x) for x in row] for row in got[0]],pair(got[1]),tuple(map(pair,got[2])))==expect);reader_cases+=1

# Full 256-entry global table with zeros/sparse multiplicities; test its leaf
# layer too. This validates unmasked arithmetic, not its commitment/PCS binding.
m=[0]*256
for i in [0,1,17,33,255]:m[i]=rng.randrange(1,100)
leaves=tuple(attempt.leaf(i,-m[i]) for i in range(256))
point=[E(0),E(1)]+[rnd() for _ in range(5)];ch=[E(1),E(0)]+[rnd() for _ in range(5)];lam=rnd()
original=[(pair(x),pair(y)) for x,y in leaves]
expect=R.direct(original,list(map(pair,point)),list(map(pair,ch)),pair(lam))
for q in [0,1,4]:
    got=execute(leaves.__getitem__,256,8,point,ch,q,lam,P)
    check(([[pair(x) for x in row] for row in got[0]],pair(got[1]),tuple(map(pair,got[2])))==expect)
    reader_cases+=1

result={'status':'PASS','seed':20261020109,'checks':checks,'verified_pins':len(pins),
    'source_fragment_mutations':mutations,'independent_inverse_cases':96,'original_fixture_cases':len(fixtures),
    'native_wrapping_reader_values':len(want),'additional_tiled_consumers':reader_cases,
    'negative_controls':controls,'elapsed_s':time.monotonic()-t0,
    'maxrss_KiB':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
    'scope':'Independent original-source basis, exponent inverse, compiled native wrapping reader; unmasked arithmetic only.'}
(H/'validation-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
