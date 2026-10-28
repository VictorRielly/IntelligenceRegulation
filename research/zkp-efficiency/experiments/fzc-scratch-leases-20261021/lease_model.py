"""Research storage protocol. Not CUDA or a native concurrency implementation.

Only a correctly bound completion event permits reuse. Message publication is
deliberately separate from last-use completion. All input words are synthetic.
"""
from dataclasses import dataclass

U64 = (1 << 64) - 1

class Refused(Exception):
    pass

@dataclass(frozen=True)
class Key:
    device: int
    context: int
    stream: int
    role: str
    flags: int

@dataclass(frozen=True)
class Ticket:
    allocation: int
    generation: int
    key: Key

@dataclass(frozen=True)
class Completion:
    ticket: Ticket
    last_sequence: int

@dataclass
class Storage:
    identity: int
    key: Key
    words: list
    generation: int = 0
    busy: bool = False
    poisoned: bool = False

class Pool:
    def __init__(self, max_words=8192):
        self.entries = []
        self.allocations = 0
        self.growths = 0
        self.reuses = 0
        self.peak_words = 0
        self.next_identity = 0
        self.max_words = max_words  # includes busy, idle, growth and quarantine
        self.cumulative_allocated_words = 0

    def acquire(self, key, count, fail=False):
        if count <= 0 or key.role not in ('mapped', 'fallback', 'tail'):
            raise Refused('invalid public request')
        # Injection models a failed acquisition, even on a warm lease; this is
        # a differential control, NOT emulation of physical allocator failures.
        if fail:
            raise Refused('acquisition failure')
        old = next((s for s in self.entries if s.key == key and not s.busy and not s.poisoned), None)
        if old is not None and len(old.words) >= count:
            s = old
            self.reuses += 1
        else:
            if sum(len(s.words) for s in self.entries) + count > self.max_words:
                raise Refused('bounded storage exhausted')
            self.next_identity += 1
            s = Storage(self.next_identity, key, [0] * count)
            self.entries.append(s)
            self.allocations += 1
            self.cumulative_allocated_words += count
            self.peak_words = max(self.peak_words, sum(len(x.words) for x in self.entries))
            if old is not None:
                self.growths += 1
                self.entries.remove(old)  # old is idle; old+new peak charged
        s.generation += 1
        s.busy = True
        # Fresh contents, including the flag at the NEW degree's offset.
        s.words[:count] = [0] * count
        ticket = Ticket(s.identity, s.generation, key)
        return Lease(s, ticket, count)

    def release(self, lease, completion):
        lease.check()
        if completion != Completion(lease.ticket, lease.seq):
            raise Refused('missing, stale or wrong completion')
        lease.storage.busy = False
        lease.closed = True

    def quarantine(self, lease):
        lease.check()
        lease.storage.poisoned = True
        # No freeing or recycling while work might still touch it. Native
        # context teardown and bounded error admission remain owner work.
        lease.closed = True

class Lease:
    def __init__(self, storage, ticket, count):
        self.storage, self.ticket, self.count = storage, ticket, count
        self.seq = 0
        self.pending = None
        self.published = False
        self.closed = False

    def check(self):
        if self.closed or not self.storage.busy or self.storage.poisoned or self.storage.generation != self.ticket.generation:
            raise Refused('invalid lease')

    def submit(self, payload):
        self.check()
        if self.pending is not None or len(payload) + 1 != self.count or any(not 0 <= x <= U64 for x in payload):
            raise Refused('bad or overlapping message')
        if self.seq == U64:
            raise Refused('sequence exhausted')
        self.seq += 1
        self.pending = tuple(payload)
        self.published = False
        return self.seq

    def publish(self, ticket):
        self.check()
        if ticket != self.ticket or self.pending is None:
            raise Refused('stale writer')
        # Atomic publication abstraction: native system fence/visibility and
        # driver semantics are prerequisites, not proven by this model.
        self.storage.words[:self.count - 1] = self.pending
        self.storage.words[self.count - 1] = self.seq
        self.published = True

    def poll(self):
        self.check()
        if self.pending is None or self.storage.words[self.count - 1] != self.seq or not self.published:
            return None
        return tuple(self.storage.words[:self.count - 1])

    def consume(self):
        out = self.poll()
        if out is None:
            raise Refused('message not published')
        self.pending = None
        return out

    def completed_event(self, ticket):
        """Called ONLY by an independent last-use device event oracle.

        This method is not a poll and must never be wired to mapped seq alone.
        A real event must cover all GPU references, including non-message work.
        """
        self.check()
        if ticket != self.ticket or (self.pending is not None and not self.published):
            raise Refused('event before last-use completion')
        return Completion(ticket, self.seq)
