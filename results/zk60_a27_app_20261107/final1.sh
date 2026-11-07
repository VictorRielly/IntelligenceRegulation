#!/bin/bash
# Lane A27, job final1 (one guarded gpu-class job): the native acceptance on this commit (accept.sh, FULL=1:
# the release CLI, the census and A26/A4/A27 tests, the device byte gates of the media app and the 8B stack,
# the full lib suite); the CLI kept as zk60_classify.a27-c1; the byte identity on the real Shieldstral export
# under fixed public test entropy (bi.sh: A26's pin, the candidate, the candidate with every A27 switch off);
# then the A/B pairs against A26 (m1: the 8-post stream; m2: one post, and the proof-only clock).
R=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6ef8e7c158543247/results/zk60_a27_app_20261107
WT=/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a6ef8e7c158543247
BIN=/Users/victorrielly/zk60-artifacts/proven-media-fast/bin
P=$R/final1.progress
say() { echo "$(date -u +%FT%TZ) $*" >> $P; }
say "start at $(git -C $WT rev-parse --short HEAD 2>/dev/null); free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
env FULL=1 /bin/bash $R/accept.sh t1
say "accept rc=$? ($(grep -c 'rc=0' $R/accept_t1.progress) steps rc=0; $(grep -cE 'MISSING|rc=[1-9]' $R/accept_t1.progress) problems)"
cp $WT/ops/zkp-mvp/gpu-metal/hashline/target/release/examples/zk60_classify $BIN/zk60_classify.a27-c1
say "candidate a27-c1 sha256 $(shasum -a 256 $BIN/zk60_classify.a27-c1 | cut -d' ' -f1)"
/bin/bash $R/bi.sh bi1 $BIN/zk60_classify.a27-c1
say "bi1 done: $(tail -1 $R/byteid_bi1.out | cut -c1-600)"
free=$(df -g /Users/victorrielly | tail -1 | awk '{print $4}')
if [ "$free" -lt 40 ]; then say "STOP: free disk $free GiB under 40"; exit 3; fi
/bin/bash $R/runs.sh m1 $R/m1.plan
say "m1 done"
/bin/bash $R/runs.sh m2 $R/m2.plan
say "m2 done"
say "all done; free disk $(df -g /Users/victorrielly | tail -1 | awk '{print $4}') GiB"
