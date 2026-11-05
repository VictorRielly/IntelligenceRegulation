# A13 one-request clocks: [ahead32+qos2] against [noahead], N = 6, alternating order (s4_d55_ab.log)

| clock | base first: mean change (pairs, test lower) | test first: mean change (pairs, test lower) | order bias solved out | means base / test |
|---|---|---|---|---|
| one request wall s | +2.3% (1, 0) | +0.8% (1, 0) | **+1.6%** | 8.563 / 8.698 |
| sealing pass s | +16.2% (1, 0) | +11.3% (1, 0) | **+13.7%** | 4.222 / 4.798 |
| sealing CPU-s | +65.6% (1, 0) | +49.6% (1, 0) | **+57.6%** | 42.350 / 66.550 |
| prove call s | -10.5% (1, 1) | -9.8% (1, 1) | **-10.2%** | 4.341 / 3.899 |
| forks phase (of the request) s | -10.6% (1, 1) | -12.9% (1, 1) | **-11.8%** | 3.878 / 3.422 |
| preflight + commit s | -11.4% (1, 1) | +24.4% (1, 0) | **+6.5%** | 0.387 / 0.399 |
