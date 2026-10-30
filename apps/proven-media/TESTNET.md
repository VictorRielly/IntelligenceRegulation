# Base Sepolia publisher

The optional publisher posts batch digests to Base Sepolia (chain 84532). Proofs
remain in the app's local content-addressed store. The contract records a digest;
it does not verify the proof or provide permanent distributed storage. The default
demo still uses the local ledger. The testnet publisher refuses fake proofs and
labels that are not bound to a verified classifier proof, including today's stub.

Implementation: `proven_media/base_sepolia.py`, `testnet_publisher.py`, and
`contracts/ProvenMediaAnchor.sol`. The latter permits only its deploying publisher
and only chain 84532. Code hash, publisher address, chain, receipt, exact event,
transaction input and canonical block are checked on every publication verification.
Three confirmations are required by the generated configuration.

## Setup

Install `requirements-testnet.txt` into the app venv. Compile with Solidity 0.8.28
using `tools/compile_anchor.py --out <artifact.json>` **through the project's build
resource guard**, after admission succeeds. Compiler settings and source SHA256
are included in the artifact. The existing offline npm cache is
`/tmp/zk60-astra-npm-cache`.

`tools/sepolia_setup.py key` creates one new throwaway key in
`$PM_PRIVATE_DIR/testnet/throwaway.sepolia-key.json` (default
`~/zk60-owner-private/proven-media/testnet/`), mode 0600, inside a 0700 directory.
`--private-dir` can select another durable directory outside the repository;
temporary and repository paths are refused before key creation.
It refuses to overwrite a key. Never supply a mainnet key. The key is not sent to
RPC, included in manifests or placed on argv. All amounts are free test ETH;
no real spending is authorized.

The Oct 26 throwaway address is
`0x775E8A2D741446d74E3f5a02244D1241eceB187d`. Funding and anchor deployment are
complete. Victor obtained free Ethereum Sepolia test ETH without a Coinbase
account. The authorized 0.01 then 0.45 test-ETH deposits through Base's official
Sepolia L1StandardBridge both credited Base Sepolia, for 0.46 test ETH total.
After deployment the read-only balance was 0.459998729693299927 test ETH.
No further funding is needed for setup. The official
[Base funding guide](https://docs.base.org/get-started/get-funds) lists faucets
for future top-ups.

Coinbase is not required. The [LearnWeb3 Base Sepolia faucet](https://learnweb3.io/faucets/base_sepolia/)
lists a GitHub sign-in option and 0.01 test ETH per day. Sign in, link GitHub,
paste the public address above, and request Base Sepolia test ETH. The wallet
already exists; the faucet only needs its public address. On Oct 28 its page
returned intermittent server errors during verification, so successful funding
must be confirmed by the read-only status command below. This route was not used
for the completed funding. Do not buy or transfer real ETH.

An address-only alternative checked on Oct 28 is the
[ZalalenA Base Sepolia faucet](https://faucet.zalalena.com/base). Its published
instructions require only the public address and CAPTCHA, with no account or
existing balance. Paste the address, complete CAPTCHA, and click **Claim Free
Base Sepolia ETH**. The page loaded during our check; a successful payout has
not been tested. Confirm any transfer on the
[wallet's Base Sepolia explorer page](https://sepolia.basescan.org/address/0x775E8A2D741446d74E3f5a02244D1241eceB187d)
and with the status command below. No wallet import or private key is needed.

The default public RPC returned HTTP 403 from this host. The provider's documented
[OnFinality Base Sepolia endpoint](https://onfinality.io/en/rpc-assistant/rpc-base-sepolia)
responded with chain 84532 and the balance. Check the existing migrated wallet
from the repository root:

```bash
apps/proven-media/.venv/bin/python apps/proven-media/tools/sepolia_setup.py status --private-dir /home/victor/zk60-owner-private/proven-media-astra-demo/testnet --rpc-url https://base-sepolia.api.onfinality.io/public
```

The existing app configuration remains at
`apps/proven-media/.testnet-private/sepolia.json`; the status tool's
`config_exists` field only describes the selected wallet directory. Its balance
check uses the same deployed publisher address.

For a new deployment, pass the chosen durable `--private-dir`, `deploy`, and
`--artifact results/zk60_astra_20261026/testnet/anchor_contract.json` to the setup
tool. Deployment persists its signed envelope before sending. Repeat `deploy` while it
reports pending; it reuses that transaction. After a canonical successful receipt
has three confirmations, it compares the entire runtime against the compiled
artifact with the publisher immutable filled in, then writes `sepolia.json`.
A revert, altered runtime, wrong chain, insufficient test ETH or excessive gas
fails closed. No replacement transaction or extra funding is sent automatically.
The setup and bridge tools pace RPC calls and retry HTTP 429 with bounded backoff.
Once `sepolia.json` exists, use `status`; another `deploy` invocation refuses.

Confirmed anchor: `0x8432eba82b1a402f4da7680f6b8f9c9fae185cbe`.
[Deployment transaction](https://sepolia.basescan.org/tx/0xfaa03b5a466ce3004f212025010e75cd902fa599c01b779d606a5524c4ac1559)
passed the canonical receipt, three-confirmation and exact runtime checks.
Public evidence is retained in
`results/zk60_astra_20261026/testnet/funding_evidence.json` and
`results/zk60_astra_20261026/testnet/deployment_evidence.json` from the repository
root. Keep the private key and deployment envelopes in the durable private directory.
The existing Oct 26 wallet was moved unchanged on Oct 30 to
`~/zk60-owner-private/proven-media-astra-demo/testnet/throwaway.sepolia-key.json`.
Its existing `.testnet-private/sepolia.json` now points to that absolute path.

## App configuration and independent checks

Select `PM_PUBLISHER=base-sepolia` and set `PM_SEPOLIA_CONFIG` to the generated
configuration when starting the app. Local data and testnet data use separate
namespaces under the public root. Keep the signing config in the private directory.
The config schema is `proven-media/base-sepolia/1`; it pins the contract runtime
hash and publisher address. A public copy for verification may omit `key_file`.

`tools/verify_publication.py` and `tools/verify_manifest.py` accept
`--sepolia-config <public-config.json>`. Read-only verification never loads a key.
Anchoring and proof verification remain separate checks; use the native verifier
when checking the proof itself.

The batch worker writes `chain/inflight.json` before broadcasting. Restarting it
polls or resends the same signed transaction. It finalizes anchors only after
confirmation and retains recovery state until all local writes are durable. A
later reorg causes verification to fail until the required canonical receipt is
present. RPC availability and trust remain operational dependencies.

## Evidence and limits

Transport/batcher tests use real local transaction signing and controlled RPC
responses, including lost-send responses, reorgs, modified events, wrong chain,
altered code and interrupted finalization. Deployment tests exercise recovery and
runtime pinning with a fixture; they are not EVM execution tests. The live testnet
deployment is now confirmed. Live anchoring and the real Shieldstral app demo are
still pending; deploying the digest anchor does not establish classifier proof
acceptance.
