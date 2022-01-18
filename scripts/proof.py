import rlp
from brownie import web3
from hexbytes import HexBytes
from trie import HexaryTrie

VOTING_ESCROW = "0x5f3b5DfEb7B28CDbD7FAba78963EE202a494e2A2"
BLOCK_NUMBER = 14000000

# https://github.com/ethereum/go-ethereum/blob/master/core/types/block.go#L69
HEADER_ORDER = (
    "parentHash",
    "sha3Uncles",
    "miner",
    "stateRoot",
    "transactionsRoot",
    "receiptsRoot",
    "logsBloom",
    "difficulty",
    "number",
    "gasLimit",
    "gasUsed",
    "timestamp",
    "extraData",
    "mixHash",
    "nonce",
    "baseFeePerGas",  # added by EIP-1559 and is ignored in legacy headers
)


def main():
    # fetch the block of interest
    block = web3.eth.get_block(BLOCK_NUMBER)
    # fetch the proof
    proof = web3.eth.get_proof(VOTING_ESCROW, [0], BLOCK_NUMBER)

    # filter only the fields needed to replicate the block hash
    header_fields = {k: block[k] for k in HEADER_ORDER}

    for field, value in header_fields.items():
        if isinstance(value, int) and value == 0:
            # 0 needs to be encoded as b'0x' not b'0x0'
            header_fields[field] = HexBytes("0x")
        else:
            # everything should be of bytes type
            header_fields[field] = HexBytes(value)

    # rlp encode to list of values (strictly maintaining the same ordering)
    rlp_input = rlp.encode(list(header_fields.values()))
    # assert the blockhash calculated matches the blockhash on-chain
    assert block["hash"] == web3.keccak(rlp_input)
    state_root = block["stateRoot"]  # root hash of the global state trie

    # get the account rlp [nonce, balance, storageHash, codehash]
    account_rlp = HexaryTrie.get_from_proof(
        state_root,
        web3.keccak(HexBytes(VOTING_ESCROW)),
        list(map(rlp.decode, proof["accountProof"])),
    )
    storage_root = rlp.decode(account_rlp)[2]  # root hash of the storage trie for the account
    assert storage_root == proof["storageHash"]

    # get the value in storage
    storage_proof = proof["storageProof"][0]
    value = HexaryTrie.get_from_proof(
        storage_root,
        # the path for a storage value is the hash of its slot
        web3.keccak(HexBytes((0).to_bytes(32, "big"))),
        list(map(rlp.decode, storage_proof["proof"])),
    )
    # decode the value
    assert value == rlp.encode(storage_proof.value)
