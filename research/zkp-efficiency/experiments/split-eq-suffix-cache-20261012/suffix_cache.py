"""Per-proof public split-Eq suffix levels; no transcript or RNG access.

The fixed boundary is chosen for the first suffix actually needed. Leading
offset supports need the entire point; start=0 omits the current coordinate.
Views borrow levels. Obsolete levels are released after the round is bound.
"""
from collections import Counter
from field import F


class SuffixCache:
    def __init__(self, point, start, n):
        if type(n) is not int or type(start) is not int or not 0 <= start <= n:
            raise ValueError('cache extent')
        if len(point) > n-start:
            raise ValueError('cache point extent')
        # Own a canonical copy, so a caller cannot mutate cached public data.
        self.key = tuple((x.a,x.b) for x in point)
        self.point = tuple(F(a,b) for a,b in self.key)
        self.start,self.n,self.end = start,n,start+len(point)
        self.base = min(1,len(point)) if start == 0 and n else 0
        self.boundary = self.base+(len(point)-self.base)//2
        self.counts = Counter()
        self.left = self._levels(self.point[self.base:self.boundary])
        self.right = self._levels(self.point[self.boundary:])
        self.next,self.pending = 0,False
        self.counts['peak_retained_entries'] = self.retained()

    def _levels(self, point):
        levels = {len(point):(F(1),)}
        self.counts['entries_built'] += 1
        for k in range(len(point)-1,-1,-1):
            tail = levels[k+1];w=point[k];other=1-w
            levels[k]=tuple([other*v for v in tail]+[w*v for v in tail])
            self.counts['build_multiplications'] += 2*len(tail)
            self.counts['build_reads'] += 2*len(tail)
            self.counts['entries_built'] += 2*len(tail)
            self.counts['coordinate_subtractions'] += 1
        return levels

    def retained(self):
        return sum(map(len,self.left.values()))+sum(map(len,self.right.values()))

    def pair(self,j,point=None,start=None):
        if j != self.next or j >= self.n or self.pending:
            raise ValueError('cache round schedule')
        if point is not None and tuple((x.a,x.b) for x in point) != self.key:
            raise ValueError('stale equality point')
        if start is not None and start != self.start:
            raise ValueError('stale support start')
        consumed=min(max(j+1-self.start,0),len(self.point))
        li=max(consumed-self.base,0) if consumed < self.boundary else self.boundary-self.base
        ri=max(consumed-self.boundary,0)
        self.pending=True
        left,right=self.left[li],self.right[ri]
        self.counts['borrowed_views'] += 2
        return left,right,len(self.point)-consumed,self.n-self.end if consumed<len(self.point) else 0

    def finish_round(self,j):
        if j != self.next or not self.pending:
            raise ValueError('cache bind schedule')
        self.pending=False;self.next+=1
        # Determine the earliest suffix needed by the next round. Keep the
        # empty level as the algebraic identity, including after support ends.
        consumed=min(max(self.next+1-self.start,0),len(self.point))
        li=min(max(consumed-self.base,0),self.boundary-self.base)
        ri=max(consumed-self.boundary,0)
        for levels,minimum in ((self.left,li),(self.right,ri)):
            for k in list(levels):
                if k < minimum:
                    self.counts['entries_released'] += len(levels.pop(k))
                    self.counts['levels_released'] += 1

    def terminal(self):
        if self.next != self.n or self.pending:
            raise ValueError('cache terminal schedule')
        return F(1)


def accounting(n,start,length):
    """Allocation-free exact model of the two construction schedules."""
    baseline_entries=baseline_mul=baseline_sub=baseline_peak=0
    for j in range(n):
        consumed=min(max(j+1-start,0),length);s=length-consumed
        a,b=s//2,s-s//2
        entries=(1<<a)+(1<<b)
        baseline_entries+=entries
        baseline_mul+=2*((1<<a)+(1<<b)-2)
        baseline_sub+=s
        baseline_peak=max(baseline_peak,entries)
    base=min(1,length) if start==0 and n else 0
    a=(length-base)//2;b=length-base-a
    candidate_entries=(1<<(a+1))+(1<<(b+1))-2
    candidate_mul=2*((1<<a)+(1<<b)-2)
    return dict(n=n,start=start,length=length,
        baseline_entries_built=baseline_entries,baseline_build_multiplications=baseline_mul,
        baseline_coordinate_subtractions=baseline_sub,baseline_peak_entries=baseline_peak,
        cache_entries_built=candidate_entries,cache_build_multiplications=candidate_mul,
        cache_coordinate_subtractions=a+b,cache_peak_entries=candidate_entries,
        cache_entries_released=max(0,candidate_entries-2),
        baseline_build_reads_native=baseline_mul//2,
        baseline_build_writes_native=baseline_mul+baseline_entries,
        cache_build_reads_two_pass=candidate_mul,cache_build_writes=candidate_entries,
        baseline_point_reverse_copies=baseline_sub,
        unchanged_weight_reads=2*((1<<n)-1),unchanged_weight_multiplications=(1<<n)-1,
        multiplication_fraction_removed_from_weight_plus_build=(baseline_mul-candidate_mul)/max(1,baseline_mul+(1<<n)-1),
        logical_cache_peak_bytes=16*candidate_entries,
        logical_extra_peak_bytes=16*(candidate_entries-baseline_peak))
