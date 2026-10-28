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
`.testnet-private/throwaway.sepolia-key.json`, mode 0600, inside a 0700 directory.
It refuses to overwrite a key. Never supply a mainnet key. The key is not sent to
RPC, included in manifests or placed on argv. All amounts are free test ETH;
no real spending is authorized.

The Oct 26 throwaway address is
`0x775E8A2D741446d74E3f5a02244D1241eceB187d`. It had zero test ETH at the last
successful status check. Fund it from a free Base Sepolia faucet. The official
[Base funding guide](https://docs.base.org/get-started/get-funds) lists faucet
options. No deployment or transaction has been sent yet.

The default public RPC returned HTTP 403 from this host. The provider's documented
[OnFinality Base Sepolia endpoint](https://onfinality.io/en/rpc-assistant/rpc-base-sepolia)
responded with chain 84532 and the balance. Commands, from the repository root:

```bash
apps/proven-media/.venv/bin/python apps/proven-media/tools/sepolia_setup.py status --rpc-url https://base-sepolia.api.onfinality.io/public
apps/proven-media/.venv/bin/python apps/proven-media/tools/sepolia_setup.py deploy --rpc-url https://base-sepolia.api.onfinality.io/public --artifact results/zk60_astra_20261026/testnet/anchor_contract.json
```

Deployment persists its signed envelope before sending. Repeat `deploy` while it
reports pending; it reuses that transaction. After a canonical successful receipt
has three confirmations, it compares the entire runtime against the compiled
artifact with the publisher immutable filled in, then writes `sepolia.json`.
A revert, altered runtime, wrong chain, insufficient test ETH or excessive gas
fails closed. No replacement transaction or extra funding is sent automatically.

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
runtime pinning with a fixture; they are not EVM execution tests. Live deployment,
live anchoring and the real Shieldstral app demo are still pending.
