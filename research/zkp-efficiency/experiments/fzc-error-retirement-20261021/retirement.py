"""Synthetic metadata-only candidate. No CUDA calls, payloads, or proof work.

The owner must close submissions before retirement. A trusted adapter supplies
successful, recorded completion frontiers; failures never manufacture a fence.
"""
from dataclasses import dataclass, field


@dataclass(frozen=True)
class Fence:
    context: int
    generation: int
    covered: dict
    success: bool = True
    recorded: bool = True


@dataclass
class Lease:
    context: int
    generation: int
    capacity: int
    last: dict = field(default_factory=dict)
    closed: bool = False
    failed: bool = False
    poisoned: bool = False
    free_uncertain: bool = False

    def submit(self, stream, ticket):
        if self.closed or self.poisoned:
            raise ValueError("submission closed")
        if ticket <= self.last.get(stream, 0):
            raise ValueError("nonmonotone submission")
        self.last[stream] = ticket

    def decision(self, fences):
        if not self.closed:
            return "hold"
        if self.poisoned or self.free_uncertain:
            return "quarantine"
        done = {}
        for f in fences:
            if (f.success and f.recorded and f.context == self.context
                    and f.generation == self.generation):
                for stream, ticket in f.covered.items():
                    done[stream] = max(ticket, done.get(stream, 0))
        if all(done.get(s, 0) >= t for s, t in self.last.items()):
            return "retire"
        return "quarantine" if self.failed else "hold"


class Budget:
    """Reserve capacity at admission, so failure cannot overflow quarantine.

Counts all held storage, including active/idle/quarantined storage. A stopped
owner must not hide a live allocation in an unaccounted leak after exhaustion.
"""
    def __init__(self, cap):
        self.cap = cap
        self.held = {}
        self.poisoned_contexts = set()

    def admit(self, key, lease):
        size = lease.capacity
        if (key in self.held or size <= 0 or lease.context in self.poisoned_contexts
                or any(x is lease for x in self.held.values())
                or self.bytes_held() + size > self.cap):
            return False
        self.held[key] = lease
        return True

    def bytes_held(self):
        return sum(x.capacity for x in self.held.values())

    def poison(self, context):
        self.poisoned_contexts.add(context)
        for lease in self.held.values():
            if lease.context == context:
                lease.poisoned = True
                lease.closed = True

    def release(self, key, fences, free_success=True):
        lease = self.held[key]
        if lease.decision(fences) != "retire":
            return False
        if not free_success:
            # A real API can report an earlier asynchronous error. Do not infer
            # whether the allocation survived, dereference it, or retry free.
            lease.free_uncertain = True
            return False
        del self.held[key]
        return True
