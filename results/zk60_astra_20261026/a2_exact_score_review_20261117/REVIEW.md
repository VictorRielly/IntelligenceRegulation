# Attention scores at the original prompt lengths

All 221,207,168 scores across the six prompts fit the native integer range of −127 through 127. For each of 26 layers, the check used the authenticated historical input to that layer and the exported normalization, query, key and rotary parameters. It evaluated all 32 heads at every ordered pair of original token positions, including positions above the causal diagonal. [Per-layer counts and extrema](RESULT.json)

| Item | Tokens | Scores | Minimum | Maximum |
| ---: | ---: | ---: | ---: | ---: |
| 3122 | 234 | 45,556,992 | −104 | 85 |
| 3446 | 174 | 25,189,632 | −99 | 74 |
| 3734 | 241 | 48,323,392 | −112 | 70 |
| 4058 | 181 | 27,257,152 | −97 | 65 |
| 4346 | 240 | 47,923,200 | −109 | 69 |
| 4670 | 180 | 26,956,800 | −95 | 64 |

The earlier padding failure occurred at layer 7 of item 3446. At the original length its 968,832 scores ranged from −89 through 52, with no clamping. The separate padded attempt preserves the four violations at pairs of added positions. [Padding diagnosis](../a2_padding_diagnosis_20261117/README.md)

The single-process check took 183.1 seconds and used 176.1 MiB peak RSS. It tests the score arithmetic using a saved input at each layer. Sequential native execution, comparison of the full witness and native proofs remain pending. [Check implementation](scores.py)
