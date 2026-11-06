# A16 the sealing pass alone (32 serial witness builds, W16R2 8B T128): means over passes (/Users/victorrielly/IntelligenceRegulation/.claude/worktrees/agent-a25af4fbe05476b8b/results/zk60_effplan_20261105/a16/raw/s1_alone.log)

| arm | where | passes | wall s | user CPU s | sys CPU s | cores busy | csw voluntary | csw involuntary | minor faults | wall vs base, base first / last / order bias out |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| spauto+a16old | a sealing pool of 8 | 4 | 3.116 | 7.29 | 2.47 | 3.1 | 0 | 43,524 | 530,718 | — |
| spauto+a16cache | a sealing pool of 8 | 4 | 2.653 | 6.83 | 2.39 | 3.5 | 0 | 44,082 | 523,761 | -14.5% / -15.3% / **-14.9%** |
| spauto+a16cache+a16quant | a sealing pool of 8 | 4 | 2.333 | 6.22 | 3.30 | 4.1 | 0 | 41,736 | 526,500 | -26.0% / -24.1% / **-25.1%** |
| spauto+a16cache+a16quant+a16norm | a sealing pool of 8 | 4 | 2.111 | 6.14 | 3.45 | 4.5 | 0 | 43,594 | 527,209 | -33.4% / -31.0% / **-32.2%** |
| spauto+a16cache+a16quant+a16norm+a16loops | a sealing pool of 8 | 4 | 2.038 | 6.34 | 4.04 | 5.1 | 0 | 45,108 | 529,185 | -35.1% / -34.0% / **-34.6%** |
| spauto+a16cache+a16quant+a16norm+a16loops+a16kernels | a sealing pool of 8 | 4 | 1.868 | 4.94 | 4.06 | 4.8 | 0 | 46,162 | 529,111 | -39.5% / -40.6% / **-40.0%** |
| spauto+a16all | a sealing pool of 8 | 4 | 1.630 | 5.09 | 4.02 | 5.6 | 0 | 43,097 | 529,008 | -47.5% / -47.8% / **-47.7%** |
| spauto+a16xoverlap | a sealing pool of 8 | 4 | 1.817 | 4.92 | 4.06 | 5.0 | 0 | 45,350 | 529,100 | -41.7% / -41.7% / **-41.7%** |
| spauto+a16xkernels | a sealing pool of 8 | 4 | 1.927 | 6.47 | 4.02 | 5.5 | 0 | 44,775 | 529,010 | -36.2% / -40.4% / **-38.3%** |
| spauto+a16xcache | a sealing pool of 8 | 4 | 2.079 | 5.54 | 3.84 | 4.5 | 0 | 43,034 | 531,002 | -34.6% / -31.9% / **-33.2%** |
| spauto+a16xquant | a sealing pool of 8 | 4 | 1.842 | 5.71 | 2.93 | 4.7 | 0 | 45,682 | 525,640 | -41.8% / -40.0% / **-40.9%** |
| spauto+a16xnorm | a sealing pool of 8 | 4 | 1.831 | 5.15 | 3.81 | 4.9 | 0 | 41,706 | 527,926 | -42.8% / -39.6% / **-41.2%** |
| spauto+a16xloops | a sealing pool of 8 | 4 | 1.832 | 4.93 | 3.60 | 4.7 | 0 | 42,403 | 527,226 | -39.6% / -42.8% / **-41.2%** |
| spauto+a16old+prod | a sealing pool of 8 | 4 | 3.223 | 7.92 | 2.40 | 3.2 | 0 | 52,242 | 525,603 | +3.2% / +3.6% / **+3.4%** |
| spauto+a16all+prod | a sealing pool of 8 | 4 | 1.672 | 5.14 | 4.06 | 5.5 | 0 | 44,147 | 529,157 | -46.9% / -45.7% / **-46.3%** |
| spauto+a16xonce+prod | a sealing pool of 8 | 4 | 1.756 | 5.78 | 4.12 | 5.6 | 0 | 50,557 | 529,075 | -44.2% / -43.1% / **-43.6%** |
| sp12+a16all | a sealing pool of 12 | 4 | 1.522 | 6.28 | 5.70 | 7.9 | 0 | 73,148 | 537,158 | -52.1% / -50.1% / **-51.1%** |
| sp16+a16all | a sealing pool of 16 | 4 | 1.741 | 7.52 | 10.43 | 10.3 | 0 | 122,582 | 542,069 | -44.3% / -43.9% / **-44.1%** |
