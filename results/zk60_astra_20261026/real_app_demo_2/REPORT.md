# Durable real classifier demo

Post `61ac12af82b9e6c36d95075db3fc91b9` contains 19 content tokens:

> The library opened early today. I borrowed a book about birds and read it by the window.

All three r16b Shieldstral category receipts passed fresh native verification, input-owner verification and full-post label checks. The app uses the three registered moderate policies. Privacy statement pending; this testnet demonstration does not settle the final product policy or privacy acceptance.

The database, original development manifest key, salt, content ids and owner openings are retained outside the repository in the mode-700 directory `/home/victor/zk60-owner-private/proven-media-astra-demo-2`. Native owner files are mode0600. This is a new post; it does not restore the first garden post’s lost openings.

## Measurements

MEASURED, n=1, shared laptop. Work totals exclude queue wait; these are not controlled performance comparisons.

| Category | Verdict | Native threads | Native prove | Pipeline work | Sampled prove RSS |
|---|---|---:|---:|---:|---:|
| sexual | no | 8 | 451.99s | 684.51s | 8.16GiB |
| violence | no | 8 | 444.04s | 678.52s | 8.19GiB |
| hate | no | 8 | 447.88s | 676.01s | 8.15GiB |

The three receipts contain 84 segments and 2,545,236,288 bytes.

## Publication and checks

- Confirmed [Base Sepolia transaction](https://sepolia.basescan.org/tx/0x6e6d5166cf17dbaaf03443dddc4d2490ddff90e8bbfd05901ede5222bbac8181). Only commitments are anchored; receipt bytes remain in the local public store.
- `stored_verify_complete.json`: three additional fresh native verifications from the content-addressed public store.
- `app_checks.json`: 11 checks of real routes, confirmed manifest references, unchanged original signer, retained salt and all three input-owner openings, feed behavior, authentication and duplicate-screening refusal.
- `input_owner_capture.json`: public terminal owner-check events and retention metadata, without private opening bytes.
- `plan.json`: original source pins, authenticated submission route, text, token count and full category plan. All sources revalidated at completion.
- Production app storage changes passed199 tests; staged batch safety changes remain separate from this r16b run.

## Browser captures

- [feed.png](screenshots/feed.png)
- [post.png](screenshots/post.png)
- [ledger.png](screenshots/ledger.png)

Captured from the actual local app with an isolated headless browser. Visual review: completed. The snapshot server is stopped.

Full benchmark fidelity metrics, classifier privacy acceptance and reviewed batch adoption remain open.
