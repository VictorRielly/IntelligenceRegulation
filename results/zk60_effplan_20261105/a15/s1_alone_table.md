# A15 the sealing pass alone (32 serial witness builds, W16R2 8B T128): means over passes (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a87fcd65642aceb6b/results/zk60_effplan_20261105/a15/s1_alone.log)

| arm | where | passes | wall s | user CPU s | sys CPU s | cores busy | csw voluntary | csw involuntary | minor faults | wall vs base, base first / last / order bias out |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| sp0 | the global pool of 32, from the calling thread | 4 | 4.024 | 14.93 | 24.94 | 9.9 | 0 | 627,768 | 530,205 | — |
| spg | the global pool of 32, entered on a worker | 4 | 3.936 | 14.71 | 23.85 | 9.8 | 0 | 612,471 | 527,101 | -4.1% / -0.2% / **-2.1%** |
| sp32 | a sealing pool of 32 | 4 | 3.839 | 13.71 | 25.73 | 10.3 | 0 | 575,901 | 525,672 | -6.6% / -2.5% / **-4.5%** |
| sp16 | a sealing pool of 16 | 4 | 3.147 | 9.40 | 7.18 | 5.3 | 0 | 174,901 | 525,713 | -23.4% / -20.1% / **-21.8%** |
| sp12 | a sealing pool of 12 | 4 | 3.050 | 8.28 | 4.44 | 4.2 | 0 | 96,762 | 525,604 | -25.5% / -22.8% / **-24.2%** |
| sp8 | a sealing pool of 8 | 4 | 2.943 | 7.12 | 2.13 | 3.1 | 0 | 36,971 | 525,558 | -28.1% / -25.5% / **-26.8%** |
| sp6 | a sealing pool of 6 | 4 | 3.147 | 6.93 | 1.26 | 2.6 | 0 | 22,541 | 525,701 | -22.6% / -21.0% / **-21.8%** |
| sp4 | a sealing pool of 4 | 4 | 3.436 | 6.65 | 0.86 | 2.2 | 0 | 10,450 | 525,507 | -16.5% / -12.6% / **-14.6%** |
| sp2 | a sealing pool of 2 | 4 | 4.537 | 6.45 | 0.61 | 1.6 | 0 | 3,119 | 526,226 | +11.2% / +14.5% / **+12.8%** |
