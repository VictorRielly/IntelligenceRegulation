"""Authored model of k_hash_cols_stream. No native code or private inputs.

Compression is pinned from the preceding authored model; the installed blake3
library provides an independently implemented cryptographic reference.
"""
import struct
from compression import IV, MASK, compress

MAX_ROWS = ((1 << 32) - 1 - 1023) // 8


def frontier(c):
    if not 0 <= c <= (MAX_ROWS + 127) // 128:
        raise ValueError('public chunk outside modelled arithmetic')
    return 0 if c == 0 else (c - 1).bit_count() + 1


def plan_for(rows, chunk):
    if not 1 <= rows <= MAX_ROWS or chunk < 1:
        raise ValueError('outside modelled positive geometry')
    if rows <= chunk:
        return [(0, rows)]
    step = max(1, chunk // 128) * 128
    return [(r, min(step, rows-r)) for r in range(0, rows, step)]


def validate_plan(rows, plan):
    at = 0
    for row0, rc in plan:
        if row0 != at or row0 % 128 or rc <= 0 or row0 + rc > rows:
            raise ValueError('invalid public launch schedule')
        if row0 + rc < rows and rc % 128:
            raise ValueError('partial nonfinal chunk')
        at += rc
    if at != rows:
        raise ValueError('incomplete public launch schedule')


class Scratch:
    def __init__(self, depth, nn, count_lane):
        self.depth, self.nn, self.count_lane = depth, nn, count_lane
        self.words = [0xA5A5A5A5] * ((8*depth + int(count_lane))*nn)
        self.begin()

    def begin(self):
        self.written = set()
        self.reads = self.writes = self.peak = 0
        self.count_reads = self.count_writes = 0

    def get(self, s, j):
        if not 0 <= s < self.depth:
            raise ValueError('CV read outside capacity')
        out = []
        for i in range(8):
            a = (8*s+i)*self.nn+j
            if a not in self.written:
                raise ValueError('stale CV consumed')
            out.append(self.words[a])
        self.reads += 8
        return tuple(out)

    def put(self, s, j, cv):
        if not 0 <= s < self.depth:
            raise ValueError('CV write outside capacity')
        for i, x in enumerate(cv):
            a = (8*s+i)*self.nn+j
            self.words[a] = x
            self.written.add(a)
        self.writes += 8
        self.peak = max(self.peak, s+1)


class Interrupted(Exception):
    pass


def run(data, rows, nn, plan, mode='stored', scratch=None, depth=24,
        fail_after=None, mutation=None):
    if not 1 <= rows <= MAX_ROWS or nn < 1 or len(data) != rows*nn:
        raise ValueError('outside modelled geometry')
    validate_plan(rows, plan)
    needed = (((rows+127)//128)-1).bit_length()
    if depth < needed:
        raise ValueError('public depth insufficient')
    if mode not in ('stored', 'first', 'derived'):
        raise ValueError('mode')
    scratch = scratch or Scratch(depth, nn, mode != 'derived')
    if scratch.depth != depth or scratch.nn != nn or scratch.count_lane != (mode != 'derived'):
        raise ValueError('scratch shape')
    scratch.begin()
    # Original baseline clears the whole backing. The first-launch variant
    # initializes only its register length. The derived variant has no lane.
    if mode == 'stored':
        scratch.words[:] = [0]*len(scratch.words)
    traces = [[] for _ in range(nn)]
    out = [None]*nn
    nchunks = (rows+127)//128
    extra_popcounts = 0
    def call(j, cv, block, counter, blen, flags):
        traces[j].append((tuple(cv), tuple(block), counter, blen, flags))
        return compress(cv, block, counter, blen, flags)
    for li, (row0, rc) in enumerate(plan):
        c0 = row0//128
        for j in range(nn):
            if mode == 'derived':
                sl = frontier(c0)
                extra_popcounts += int(c0 != 0)
                if mutation == 'eager_count':
                    sl = c0.bit_count()
                elif mutation == 'off_by_one':
                    sl = c0.bit_count()+1
            elif mode == 'first' and row0 == 0:
                sl = 0
            else:
                sl = scratch.words[8*depth*nn+j]
                scratch.count_reads += 1
            for c in range(c0, (row0+rc+127)//128):
                last = c+1 == nchunks
                while sl > c.bit_count():
                    cv = call(j, IV, scratch.get(sl-2,j)+scratch.get(sl-1,j), 0, 64, 4)
                    scratch.put(sl-2,j,cv)
                    sl -= 1
                cv = IV
                clen = min(1024, rows*8-c*1024)
                for b in range((clen+63)//64):
                    blen = min(64,clen-b*64)
                    flags = (1 if b == 0 else 0) | (2 if b*64+blen == clen else 0)
                    if last and sl == 0 and b*64+blen == clen:
                        flags |= 8
                    block = []
                    for e in range(c*128+b*8,c*128+b*8+8):
                        # Validate chunk-local addressing, including zero-tail.
                        if e < rows:
                            if not row0 <= e < row0+rc:
                                raise ValueError('encoded chunk address outside view')
                            v = data[e*nn+j]
                        else:
                            v = 0
                        if mutation == 'endian':
                            v = int.from_bytes(v.to_bytes(8,'little'),'big')
                        block.extend((v&MASK,v>>32))
                    if mutation == 'no_root':
                        flags &= ~8
                    cv = call(j,cv,block,0 if mutation == 'local_counter' else c,blen,flags)
                if last:
                    for s in range(sl-1,-1,-1):
                        flags = 4 | (8 if s == 0 else 0)
                        if mutation == 'no_root':
                            flags &= ~8
                        cv = call(j,IV,scratch.get(s,j)+cv,0,64,flags)
                    out[j] = struct.pack('<8I',*cv)
                    break  # Native returns before the count store on final launch.
                scratch.put(sl,j,cv)
                sl += 1
            if out[j] is None and mode != 'derived':
                scratch.words[8*depth*nn+j] = sl
                scratch.count_writes += 1
        if fail_after == li+1:
            raise Interrupted('synthetic post-launch failure; no proof output')
    if any(x is None for x in out):
        raise ValueError('missing final leaf')
    return out, scratch, traces, extra_popcounts
