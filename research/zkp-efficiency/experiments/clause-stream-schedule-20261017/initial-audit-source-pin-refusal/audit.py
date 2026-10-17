"""Independent AST register-use audit and immutable-input integrity checks."""
import ast,datetime,hashlib,json,os,resource,signal
from collections import Counter
from pathlib import Path
from generate import build,build_original
from scheduler import reorder
from support_model import config

HERE=Path(__file__).resolve().parent


def audit_body(graph,outputs,source):
    fn=ast.parse(source).body[0]
    body=fn.body[:-1]
    assert len(body)==len(graph.nodes)
    remaining=Counter(x for _,a,b in graph.nodes for x in (a,b))
    remaining.update(outputs)
    stored={};peak=0;checks=0
    def token(node):
        if isinstance(node,ast.Name) and node.id in stored:return stored[node.id]
        return ast.unparse(node)
    for i,(statement,(op,a,b)) in enumerate(zip(body,graph.nodes)):
        assert isinstance(statement,ast.Assign) and len(statement.targets)==1
        assert isinstance(statement.value,ast.BinOp)
        # Compare public external expressions structurally too, since ast
        # unparsing can change quote style but must not change indices/names.
        for node,expected in [(statement.value.left,a),(statement.value.right,b)]:
            actual=token(node)
            assert ast.dump(ast.parse(actual,mode='eval'))==ast.dump(ast.parse(expected,mode='eval')),(i,actual,expected)
            checks+=1
        assert type(statement.value.op) is dict(add=ast.Add,sub=ast.Sub,mul=ast.Mult,mul_base=ast.Mult)[op]
        remaining[a]-=1;remaining[b]-=1
        target=statement.targets[0].id
        if target in stored:
            assert remaining[stored[target]]==0,(i,'premature overwrite',target)
            checks+=1
        stored[target]='v'+str(i)
        live={x for x in stored.values() if remaining[x]>0}
        peak=max(peak,len(live));checks+=1
    assert isinstance(fn.body[-1],ast.Return)
    for node,expected in zip(fn.body[-1].value.elts,outputs):
        assert token(node)==expected
        checks+=1
    return dict(checks=checks,peak_live_logical_temporaries=peak)


def main():
    signal.alarm(59);resource.setrlimit(resource.RLIMIT_CPU,(59,59))
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});os.nice(19)
    result=json.loads((HERE/'result.json').read_text());checks=0;records=[]
    assert result['status']=='passed' and json.loads((HERE/'execution.json').read_text())['exit_code']==0
    for item in result['generated_shapes']:
        cfg=config((False,False),ls=item['ls'],lookup_count=item['lookup_count'])
        graph,out=build(cfg,item['mask_active'])
        original,original_out=build_original(cfg,item['mask_active'])
        order=graph.schedule_record['order']
        assert sorted(order)==list(range(len(original.nodes)));checks+=1
        # Independent comparison against the pre-scheduling DAG. Relabel each
        # original operand from the recorded permutation; preserve operand
        # order even for commutative operations, outputs and dead operations.
        mapping={old:new for new,old in enumerate(order)}
        def cv(x):
            if x.startswith('v') and x[1:].isdigit():return 'v'+str(mapping[int(x[1:])])
            return x
        for new,old in enumerate(order):
            op,a,b=original.nodes[old]
            assert graph.nodes[new]==(op,cv(a),cv(b));checks+=1
            for x in graph.nodes[new][1:]:
                if x.startswith('v') and x[1:].isdigit():assert int(x[1:])<new;checks+=1
        assert out==tuple(cv(x) for x in original_out);checks+=1
        tag=f'ls{item["ls"]}-lk{item["lookup_count"]}-mask{int(item["mask_active"])}'
        for suffix in ('ssa','recycled'):
            source=(HERE/'generated'/(tag+'-'+suffix+'.py')).read_text()
            record=audit_body(graph,out,source)
            assert record['peak_live_logical_temporaries']==item['generated'][suffix]['peak_live_logical_temporaries']
            checks+=record['checks']+1;records.append(dict(tag=tag,kind=suffix,**record))
    # A genuine bad register assignment must fail this structural audit.
    graph,out=build(config((False,False),ls=3),False)
    src=(HERE/'generated/ls3-lk15-mask0-recycled.py').read_text().splitlines()
    src[2]=src[2].replace(' = ',' = F() + ',1)
    try:audit_body(graph,out,'\n'.join(src)+'\n')
    except AssertionError:checks+=1
    else:raise AssertionError('corrupt AST escaped audit')
    original,original_out=build_original(config((False,False),ls=3),True)
    order=list(range(len(original.nodes)))
    for label,bad in [('drop',order[:-1]),('duplicate',order+[0]),('dependency',list(reversed(order)))]:
        try:reorder(original,original_out,bad)
        except ValueError:checks+=1
        else:raise AssertionError(label+' schedule admitted')
    command=json.loads((HERE/'command.json').read_text())
    for name,digest in command['source_sha256'].items():
        assert hashlib.sha256((HERE/name).read_bytes()).hexdigest()==digest,name
        checks+=1
    owner=[]
    for rec in json.loads((HERE/'startup-manifest.json').read_text()):
        p=Path(rec['path'])
        if HERE.parents[1] not in p.parents:
            same=hashlib.sha256(p.read_bytes()).hexdigest()==rec['sha256']
            owner.append(dict(path=str(p),unchanged=same));checks+=1
    pins=json.loads((HERE/'native-current-comparison.json').read_text())
    for pin in pins:
        assert hashlib.sha256(Path(pin['path']).read_bytes()).hexdigest()==pin['sha256']
        checks+=1
    manifest={str(p.relative_to(HERE)):hashlib.sha256(p.read_bytes()).hexdigest()
              for p in sorted(HERE.rglob('*')) if p.is_file() and p.name not in ('audit.json','final-manifest.json')}
    (HERE/'final-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    output=dict(status='passed',checks=checks,generated_bodies=records,owner_memory=owner,
                negative_control='corrupt generated RHS rejected; dropped/duplicated/use-before-definition schedules refused',
                dag_equivalence='Exact operation/operand/output correspondence under public permutation; no elimination or recomputation.',
                target_16_met=False,optimality_claim=False,
                completed_at_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
    (HERE/'audit.json').write_text(json.dumps(output,indent=2)+'\n')
    print(json.dumps({k:v for k,v in output.items() if k not in ('generated_bodies','owner_memory')}))


if __name__=='__main__':main()
