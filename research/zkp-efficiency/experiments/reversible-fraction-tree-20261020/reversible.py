"""Research-only reversible fraction storage; native-field unmasked arithmetic.

Leaves stay in natural source order. A subtree root occupies its first leaf's
slot; the root of its right half survives each upward step. This uses strided
reads, unlike OpenVM's bit-reversed/contiguous implementation. No external code
is imported. No claims, masks, transcript or commitments are constructed.
"""
from fp2 import E


class Tree:
    def __init__(self, read, n):
        if n < 2 or n & (n-1):
            raise ValueError('power-of-two leaves >=2 required')
        self.n = n
        self.depth = n.bit_length()-1
        self.active_depth = self.depth
        self.data = []
        self.count = dict(source_reads=0, build_mul=0, build_add=0,
                          recover_mul=0, recover_sub=0, inversions=0,
                          prefix_peak_E=0, writes=0)
        for i in range(n):
            a,b = read(i)
            if b == 0:
                # Must check even for numerator zero. Not a native refusal gate.
                raise ValueError('zero denominator')
            self.data.append((a,b))
            self.count['source_reads'] += 1
        self.pair_capacity = n

    def build(self):
        if self.active_depth != self.depth:
            raise ValueError('build requires restored leaves')
        stride = 1
        while stride < self.n:
            for i in range(0, self.n, 2*stride):
                a,b = self.data[i]
                c,d = self.data[i+stride]
                self.data[i] = (a*d+c*b, b*d)
                self.count['build_mul'] += 3
                self.count['build_add'] += 1
                self.count['writes'] += 1
            stride *= 2
        self.active_depth = 0
        return self.data[0]

    def _restore(self, i, j, inv):
        a,b = self.data[i]
        c,d = self.data[j]
        left_d = b*inv
        self.data[i] = ((a-c*left_d)*inv, left_d)
        self.count['recover_mul'] += 3
        self.count['recover_sub'] += 1
        self.count['writes'] += 1

    def expand(self, mode='batch'):
        if self.active_depth >= self.depth:
            raise ValueError('no more layers')
        if mode not in ('batch', 'individual'):
            raise ValueError('mode')
        m = 1 << self.active_depth
        step = self.n // (2*m)
        if mode == 'individual':
            for k in range(m):
                i = 2*k*step
                self._restore(i, i+step, self.data[i+step][1].inv())
                self.count['inversions'] += 1
        else:
            # Optimized Montgomery pass: m prefix elements; no inverse-output
            # array or copied denominator array. Exactly 3m-3 batch multiplies.
            prefix = [self.data[step][1]]
            if prefix[0] == 0:
                raise ValueError('zero denominator')
            for k in range(1,m):
                d = self.data[(2*k+1)*step][1]
                if d == 0:
                    raise ValueError('zero denominator')
                prefix.append(prefix[-1]*d)
                self.count['recover_mul'] += 1
            self.count['prefix_peak_E'] = max(self.count['prefix_peak_E'], m)
            suffix_inverse = prefix[-1].inv()
            self.count['inversions'] += 1
            for k in range(m-1, 0, -1):
                i = 2*k*step
                inv_d = suffix_inverse*prefix[k-1]
                suffix_inverse = suffix_inverse*self.data[i+step][1]
                self.count['recover_mul'] += 2
                self._restore(i,i+step,inv_d)
            self._restore(0,step,suffix_inverse)
            del prefix
        self.active_depth += 1

    def layer(self):
        """Nonmutating logical children in original adjacent-subtree order."""
        stride = self.n >> self.active_depth
        for j in range(1 << self.active_depth):
            yield self.data[j*stride]


def consume(tree, point, challenges, lam, prefix_rounds=0):
    """Feed restored storage to the previously tested cubic consumer.

    Consumer scratch is separate. It cannot fold this reversible buffer: doing
    so destroys retained right children needed to restore the next layer.
    """
    from tiled_fp2 import consumer
    stats = dict(scans=0, leaves=0, internal=0, fold_scalar_updates=0,
                 stream_eq_products=0, tree_node_reads=0)
    def source():
        stats['scans'] += 1
        for x in tree.layer():
            stats['tree_node_reads'] += 1
            yield x
    g = consumer(source, 1 << (tree.active_depth-1), point,
                 prefix_rounds, lam, 2**64-2**32+1, stats)
    rows=[]
    try:
        row=next(g)
        for r in challenges:
            rows.append(row)
            row=g.send(r)
    except StopIteration as done:
        if len(rows) != len(challenges):
            raise ValueError('challenge count')
        return rows,done.value[0],done.value[1],stats
    raise ValueError('missing challenges')


def capacities(n, q=0):
    """Selected-array reservation with current consumer; E is 16 native bytes.

    Prefix freed before consumer; leaf buffer persists. Consumer reserves four
    full planes, including inactive tails, and a tile. Factor tables retained
    per round count too. Scalars/allocator/PCS/private protocol are excluded.
    """
    log=n.bit_length()-1
    assert n>=2 and n==1<<log and 0<=q<=min(4,log-1)
    def factors(k):
        return (1<<(k//2))+(1<<(k-k//2))
    peak=2*n
    peak_phase='build'
    consumer_peak=0
    for depth in range(1,log+1):
        m=1<<(depth-1);k=depth-1;localq=min(q,k)
        # Reconstruction and consumer do not overlap; backing reuse required.
        restore=2*n+m
        prefix_phase=max([4*(1<<(t+1))+factors(k-t-1)
                          for t in range(localq)]+[0])
        resident=4*(m>>localq)
        materialize=resident+4*(1<<localq)
        later=resident+max([factors(k-t-1) for t in range(localq,k)]+[0])
        use=2*n+max(prefix_phase,materialize,later)
        consumer_peak=max(consumer_peak,use)
        val=max(restore,use)
        if val>peak:peak=val;peak_phase=f'depth{depth}'+('/restore' if restore>=use else '/consumer')
    return dict(n=n,q=q,tree_E=2*n,prefix_peak_E=n//2,
                immutable_tree_E=4*n-2,selected_peak_E=peak,
                selected_peak_bytes=16*peak,peak_phase=peak_phase,
                consumer_peak_E=consumer_peak,
                scope='Native E payload model only; no masks/CFS/PCS/allocator/driver/source owners')
