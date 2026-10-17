"""Public DAG scheduling only: no operation elimination, recomputation or CSE.

All candidate choices depend on expression indices/dependencies and liveness,
never on field/witness values. Standalone standard-library research code.
"""
import itertools
from collections import Counter


def ref(x):
    return int(x[1:]) if x.startswith('v') and x[1:].isdigit() else None


def peak(graph, outputs, order):
    remaining=Counter(x for _,a,b in graph.nodes for x in (a,b))
    remaining.update(outputs)
    live=set(); high=0
    for i in order:
        _,a,b=graph.nodes[i]
        for x in (a,b):
            remaining[x]-=1
            if remaining[x]==0:live.discard(x)
        name='v'+str(i)
        if remaining[name]:live.add(name)
        high=max(high,len(live))
    return high


def candidates(graph, outputs):
    n=len(graph.nodes)
    deps=[tuple(dict.fromkeys(ref(x) for x in (a,b) if ref(x) is not None))
          for _,a,b in graph.nodes]
    heights=[];weights=[]
    for ds in deps:
        heights.append(1+max((heights[d] for d in ds),default=0))
        weights.append(1+sum(weights[d] for d in ds))
    # Depth-first orders group work along output/clause dependencies; the
    # existing global graph is retained so shared values are never recomputed.
    roots=[ref(x) for x in outputs if ref(x) is not None]
    for roots_order in itertools.permutations(roots):
        for policy in ('forward','reverse','height','weight'):
            seen=set();order=[]
            def visit(i):
                if i in seen:return
                ds=list(deps[i])
                if policy=='reverse':ds.reverse()
                if policy=='height':ds.sort(key=lambda d:(-heights[d],d))
                if policy=='weight':ds.sort(key=lambda d:(-weights[d],d))
                for d in ds:visit(d)
                seen.add(i);order.append(i)
            for i in roots_order:visit(i)
            for i in range(n):visit(i) # preserve even dead pure operations
            yield 'dfs-'+policy+'-'+','.join(map(str,roots_order)),order
    # Ready-list schedules favor consuming last users; tie breakers avoid
    # assuming depth-first output order alone is best for a multi-output DAG.
    users=[[] for _ in range(n)]
    for i,ds in enumerate(deps):
        for d in ds:users[d].append(i)
    for tie in ('early','late','deep','shallow','weight'):
        remaining=Counter(x for _,a,b in graph.nodes for x in (a,b));remaining.update(outputs)
        pending=list(map(len,deps));ready={i for i,x in enumerate(pending) if x==0}
        order=[]
        while ready:
            def score(i):
                uses=Counter(graph.nodes[i][1:])
                deaths=sum(ref(x) is not None and remaining[x]==v for x,v in uses.items())
                second={'early':i,'late':-i,'deep':-heights[i],
                        'shallow':heights[i],'weight':-weights[i]}[tie]
                return (-deaths,second,i)
            i=min(ready,key=score);ready.remove(i);order.append(i)
            for x in graph.nodes[i][1:]:remaining[x]-=1
            for u in users[i]:
                pending[u]-=1
                if pending[u]==0:ready.add(u)
        yield 'ready-'+tie,order


def reorder(graph, outputs, order):
    if sorted(order)!=list(range(len(graph.nodes))):
        raise ValueError('schedule must contain each operation once')
    new=type(graph)();mapping={}
    def cv(x):
        if ref(x) is None:return x
        if x not in mapping:raise ValueError('use before definition')
        return mapping[x]
    for i in order:
        op,a,b=graph.nodes[i]
        mapping['v'+str(i)]=new.op(op,cv(a),cv(b))
    return new,tuple(cv(x) for x in outputs)


def schedule(graph, outputs):
    baseline=list(range(len(graph.nodes)))
    records=[('original',baseline,peak(graph,outputs,baseline))]
    records.extend((name,order,peak(graph,outputs,order)) for name,order in candidates(graph,outputs))
    name,order,best=min(records,key=lambda x:x[2])
    new,out=reorder(graph,outputs,order)
    assert new.counts==graph.counts and len(new.nodes)==len(graph.nodes)
    return new,out,dict(policy=name,baseline_peak=records[0][2],scheduled_peak=best,
                        candidate_count=len(records),order=order,
                        frontier_histogram=dict(Counter(x[2] for x in records)))
