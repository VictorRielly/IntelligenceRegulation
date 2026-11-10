#!/bin/bash
# Lane A28, job final1 (one guarded gpu-class job): the final candidate's native acceptance on the COMMITTED tree
# (accept.sh, FULL=1: the release CLI rebuilt, every gate, the full lib suite), the rebuilt CLI compared with the
# kept candidate binary (the same SHA-256, or the job stops: no binary is pinned whose sources are not this
# commit), then the byte identity on the real export (bi3.sh, both parts).
# usage: final1.sh <accept tag> <kept candidate binary>
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6d02411a78ede69c/results/zk60_a28_app_20261107
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6d02411a78ede69c
TAG=$1; CAND=$2
P=$R/final1.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "start at $(git -C $WT rev-parse --short HEAD); uncommitted changes under ops/ and apps/: $(git -C $WT status --short -- ops apps | wc -l | tr -d ' '); free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
env FULL=1 /bin/bash $R/accept.sh $TAG
say "accept rc=$? ($(grep -c 'rc=0' $R/accept_$TAG.progress) steps rc=0; $(grep -cE 'MISSING|rc=[1-9]' $R/accept_$TAG.progress) lines with a nonzero rc or MISSING: the full suite's rc=101 with its 3 known failures is one)"
if grep -qE "MISSING|test build rc=[1-9]|release CLI rc=[1-9]" $R/accept_$TAG.progress; then say "STOP: a gate failed"; exit 2; fi
a=$(shasum -a 256 $WT/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_classify | cut -d' ' -f1)
b=$(shasum -a 256 $CAND | cut -d' ' -f1)
say "the committed tree's CLI $a"
say "the kept candidate      $b ($CAND)"
if [ "$a" != "$b" ]; then say "STOP: the kept candidate is not this commit's build"; exit 4; fi
free=$(df -g /Users/victorrielly | tail -1 | awk '{print $4}')
if [ "$free" -lt 40 ]; then say "STOP: free disk $free GiB under 40"; exit 3; fi
/bin/bash $R/bi3.sh bi_$TAG $CAND
say "byte identity: $(grep -E 'part [ab]' $R/bi_$TAG.progress | cut -c1-500 | tr '\n' ' ')"
say "all done; free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
