"""Base Sepolia transport: local throwaway signing, pinned contract, fail-closed reads.

RPC checks use chain 84532 exclusively. Signed envelopes are persisted by the
publisher BEFORE broadcast so uncertain submission retries the same transaction.
No private key is passed on argv, sent to RPC, or put in publication records.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import stat
import time
import urllib.error
import urllib.request
from urllib.parse import urlsplit

from .publisher import PublishError

CHAIN_ID = 84532
CHAIN_NAME = "base-sepolia"
KEY_SCHEMA = "proven-media/base-sepolia-throwaway-key/1"
ANCHOR_SIGNATURE = "anchor(bytes32,uint256,bytes32)"
EVENT_SIGNATURE = "Anchored(bytes32,uint256,bytes32)"


def keccak(data: bytes) -> bytes:
    try:
        from eth_utils import keccak as impl
    except ImportError as e:
        raise PublishError("install requirements-testnet.txt for Base Sepolia support") from e
    return bytes(impl(data))


def hex_bytes(value: str, n: int) -> bytes:
    if not isinstance(value, str):
        raise PublishError("expected hex text")
    try:
        raw = bytes.fromhex(value.removeprefix("0x"))
    except ValueError as e:
        raise PublishError("invalid hex") from e
    if len(raw) != n:
        raise PublishError(f"expected {n} bytes")
    return raw


def anchor_data(root: str, count: int, batch_hash: str) -> str:
    if type(count) is not int or not 1 <= count <= 1000:
        raise PublishError("batch count outside 1..1000")
    r, b = hex_bytes(root, 32), hex_bytes(batch_hash, 32)
    if not any(r) or not any(b):
        raise PublishError("empty batch digest")
    return "0x" + (keccak(ANCHOR_SIGNATURE.encode())[:4] + r + count.to_bytes(32, "big") + b).hex()


def create_throwaway_key(path: Path) -> str:
    from eth_account import Account
    path = Path(path)
    account = Account.create()
    # Exclusive creation, no overwrite, symlink, or briefly world-readable file.
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump({"schema": KEY_SCHEMA, "chain_id": CHAIN_ID, "address": account.address,
                   "private_key": account.key.hex()}, f)
        f.flush()
        os.fsync(f.fileno())
    return account.address


def read_throwaway_key(path: Path):
    from eth_account import Account
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
        with os.fdopen(fd) as f:
            s = os.fstat(f.fileno())
            if not stat.S_ISREG(s.st_mode) or stat.S_IMODE(s.st_mode) != 0o600 or s.st_uid != os.getuid():
                raise PublishError("throwaway key must be an owned regular file with mode 0600")
            data = json.load(f)
        if data.get("schema") != KEY_SCHEMA or data.get("chain_id") != CHAIN_ID:
            raise PublishError("only a generated Base Sepolia throwaway key is accepted")
        account = Account.from_key(data["private_key"])
        if account.address != data.get("address"):
            raise PublishError("throwaway key address mismatch")
        return account
    except (OSError, ValueError, KeyError) as e:
        raise PublishError("invalid throwaway key file") from e


class BaseSepoliaRPC:
    def __init__(self, rpc_url: str, contract: str, runtime_code_hash: str,
                 publisher_address: str, key_path: Path | None = None,
                 confirmations: int = 3, max_fee_per_gas: int = 2_000_000_000,
                 gas_limit: int = 100_000):
        url = urlsplit(rpc_url)
        if url.scheme != "https" or not url.hostname or url.username or url.password:
            raise PublishError("Base Sepolia RPC requires an HTTPS URL without embedded credentials")
        self.rpc_url = rpc_url
        self.contract = "0x" + hex_bytes(contract, 20).hex()
        self.runtime_code_hash = hex_bytes(runtime_code_hash, 32).hex()
        self.publisher_address = "0x" + hex_bytes(publisher_address, 20).hex()
        self.key_path = Path(key_path) if key_path else None
        if type(confirmations) is not int or confirmations < 1:
            raise PublishError("at least one confirmation is required")
        if not 21_000 <= gas_limit <= 200_000 or not 0 < max_fee_per_gas <= 10_000_000_000:
            raise PublishError("testnet gas bounds out of range")
        self.confirmations, self.gas_limit, self.max_fee = confirmations, gas_limit, max_fee_per_gas

    def call(self, method: str, params: list):
        request = urllib.request.Request(self.rpc_url, data=json.dumps(
            {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode(),
            headers={"Content-Type": "application/json"})
        for attempt in range(4):
            try:
                with urllib.request.urlopen(request, timeout=15) as response:
                    data = response.read(4 * 1024 * 1024 + 1)
                if len(data) > 4 * 1024 * 1024:
                    raise ValueError("oversized RPC response")
                result = json.loads(data)
                if result.get("id") != 1 or "error" in result or "result" not in result:
                    raise ValueError("RPC refused or malformed response")
                return result["result"]
            except urllib.error.HTTPError as e:
                # Retry the identical request only for explicit transient HTTP
                # responses. A broadcast retains its signed bytes and nonce;
                # uncertain delivery still uses the durable batch journal.
                if e.code not in (429, 502, 503, 504) or attempt == 3:
                    raise PublishError(f"Base Sepolia RPC failed for {method}") from e
                delay = 2 ** (attempt + 1)
                retry_after = (e.headers or {}).get('Retry-After', '')
                if retry_after.isdigit():
                    if int(retry_after) > 30:
                        raise PublishError(f"Base Sepolia RPC retry deferred for {method}") from e
                    delay = max(delay, int(retry_after))
                e.close()
                time.sleep(delay)
            except (OSError, ValueError) as e:
                raise PublishError(f"Base Sepolia RPC failed for {method}") from e

    def check_chain(self):
        if int(self.call("eth_chainId", []), 16) != CHAIN_ID:
            raise PublishError("refusing non-Base-Sepolia chain")

    def check_contract(self):
        self.check_chain()
        code = bytes.fromhex(self.call("eth_getCode", [self.contract, "latest"]).removeprefix("0x"))
        if not code or keccak(code).hex() != self.runtime_code_hash:
            raise PublishError("anchor contract runtime code does not match its pin")
        owner = self.call("eth_call", [{"to": self.contract,
            "data": "0x" + keccak(b"publisher()")[:4].hex()}, "latest"])
        if hex_bytes(owner, 32) != bytes(12) + hex_bytes(self.publisher_address, 20):
            raise PublishError("anchor contract names another publisher")

    def prepare(self, root: str, count: int, batch_hash: str) -> dict:
        self.check_contract()
        if self.key_path is None:
            raise PublishError("publisher is read-only: no throwaway key configured")
        account = read_throwaway_key(self.key_path)
        if account.address.lower() != self.publisher_address:
            raise PublishError("throwaway key does not own the anchor contract")
        data = anchor_data(root, count, batch_hash)
        nonce = int(self.call("eth_getTransactionCount", [account.address, "pending"]), 16)
        base_fee = int(self.call("eth_getBlockByNumber", ["latest", False])["baseFeePerGas"], 16)
        tip = min(int(self.call("eth_maxPriorityFeePerGas", []), 16), self.max_fee // 10)
        fee = base_fee * 2 + tip
        if fee > self.max_fee:
            raise PublishError("testnet fee exceeds configured limit")
        estimate = int(self.call("eth_estimateGas", [{"from": account.address, "to": self.contract,
                             "value": "0x0", "data": data}]), 16)
        gas = max(21_000, (estimate * 125 + 99) // 100)
        if gas > self.gas_limit:
            raise PublishError("anchor gas estimate exceeds configured limit")
        tx = {"chainId": CHAIN_ID, "nonce": nonce, "to": self.contract,
              "value": 0, "data": data, "gas": gas, "maxFeePerGas": fee,
              "maxPriorityFeePerGas": tip, "type": 2}
        # eth-account requires checksum addresses for signing.
        from eth_utils import to_checksum_address
        tx["to"] = to_checksum_address(self.contract)
        signed = account.sign_transaction(tx)
        return {"transaction": tx, "raw_transaction": "0x" + signed.raw_transaction.hex(),
                "tx_hash": "0x" + signed.hash.hex()}

    def broadcast(self, envelope: dict) -> str:
        self.check_contract()
        raw = bytes.fromhex(envelope["raw_transaction"].removeprefix("0x"))
        tx_hash = "0x" + keccak(raw).hex()
        if tx_hash != envelope["tx_hash"]:
            raise PublishError("signed transaction hash mismatch")
        # Decode the signed envelope; never trust its accompanying JSON metadata.
        from eth_account import Account
        from eth_account.typed_transactions import TypedTransaction
        from hexbytes import HexBytes
        tx = TypedTransaction.from_bytes(HexBytes(raw)).as_dict()
        if (tx["chainId"] != CHAIN_ID or bytes(tx["to"]) != hex_bytes(self.contract, 20)
                or tx["value"] != 0 or tx["gas"] > self.gas_limit or tx["maxFeePerGas"] > self.max_fee
                or Account.recover_transaction(raw).lower() != self.publisher_address
                or bytes(tx["data"]).hex() != envelope["transaction"]["data"].removeprefix("0x")):
            raise PublishError("signed envelope violates testnet publication constraints")
        known = self.call("eth_getTransactionByHash", [tx_hash])
        if known is None:
            got = self.call("eth_sendRawTransaction", ["0x" + raw.hex()])
            if got.lower() != tx_hash:
                raise PublishError("RPC returned another transaction hash")
        return tx_hash

    def confirmed(self, tx_hash: str, root: str, count: int, batch_hash: str) -> dict | None:
        self.check_contract()
        tx_hash = "0x" + hex_bytes(tx_hash, 32).hex()
        receipt = self.call("eth_getTransactionReceipt", [tx_hash])
        if receipt is None:
            return None
        if int(receipt["status"], 16) != 1:
            raise PublishError("anchor transaction reverted")
        tx = self.call("eth_getTransactionByHash", [tx_hash])
        if not tx or (tx.get("to") or "").lower() != self.contract or tx["from"].lower() != self.publisher_address:
            raise PublishError("anchor transaction sender or destination mismatch")
        if int(tx.get("chainId", "0x0"), 16) != CHAIN_ID or int(tx["value"], 16) != 0:
            raise PublishError("anchor transaction chain or value mismatch")
        if tx["input"].lower() != anchor_data(root, count, batch_hash):
            raise PublishError("anchor transaction does not bind this batch")
        height = int(receipt["blockNumber"], 16)
        block = self.call("eth_getBlockByNumber", [hex(height), False])
        if not block or block["hash"].lower() != receipt["blockHash"].lower():
            return None  # reorg: never publish an orphaned receipt as confirmed
        if (tx.get("blockHash") or "").lower() != block["hash"].lower():
            raise PublishError("transaction and receipt blocks differ")
        if receipt.get("transactionHash", "").lower() != tx_hash:
            raise PublishError("receipt names another transaction")
        event = "0x" + keccak(EVENT_SIGNATURE.encode()).hex()
        topics = [event, "0x" + hex_bytes(root, 32).hex()]
        data = "0x" + (count.to_bytes(32, "big") + hex_bytes(batch_hash, 32)).hex()
        matches = [log for log in receipt.get("logs", []) if not log.get("removed", False)
                   and log.get("address", "").lower() == self.contract
                   and [t.lower() for t in log.get("topics", [])] == topics
                   and log.get("data", "").lower() == data
                   and log.get("transactionHash", "").lower() == tx_hash
                   and log.get("blockHash", "").lower() == block["hash"].lower()]
        if len(matches) != 1:
            raise PublishError("missing or ambiguous Anchored event")
        current = int(self.call("eth_blockNumber", []), 16)
        if current - height + 1 < self.confirmations:
            return None
        return {"tx_hash": tx_hash, "block_number": height, "block_hash": block["hash"],
                "confirmations": current - height + 1, "chain_id": CHAIN_ID,
                "root": root, "count": count, "batch_file_hash": batch_hash}
