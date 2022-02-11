# @version 0.3.1
"""
@title Storage Oracle
@license MIT
@author CurveFi
"""


# RLP CONSTANTS: https://eth.wiki/fundamentals/rlp
STRING_SHORT: constant(uint256) = 128  # 0x80
STRING_LONG: constant(uint256) = 183  # 0xb7
LIST_SHORT: constant(uint256) = 192  # 0xc0
LIST_LONG: constant(uint256) = 247  # 0xf7

MAX_SIZE: constant(uint256) = 65535  # ~65 KB


@pure
@external
def _payload_offset(_byte: uint256) -> uint256:
    """
    @dev Get the number of bytes until the start of the data
    """
    # single item
    if _byte < STRING_SHORT:
        return 0
    # short string or short list, _byte <= 0xb7 or (0xc0 <= _byte <= 0xf7)
    elif _byte < STRING_LONG + 1 or (LIST_SHORT - 1 < _byte and _byte < LIST_LONG + 1):
        return 1
    # long string
    elif _byte < LIST_SHORT:
        return _byte - STRING_LONG + 1
    # long list
    else:
        return _byte - LIST_LONG + 1


@pure
@external
def _item_length(_bytes: Bytes[9]) -> uint256:
    """
    @dev Get the length in bytes of the data payload
    """
    byte0: uint256 = convert(slice(_bytes, 0, 1), uint256)
    if byte0 < STRING_SHORT:
        return 1
    elif byte0 < STRING_LONG + 1:
        return byte0 - STRING_SHORT
    elif byte0 < LIST_SHORT:
        return convert(slice(_bytes, 1, byte0 - STRING_LONG), uint256)
    elif byte0 < LIST_LONG + 1:
        return byte0 - LIST_SHORT
    else:
        return convert(slice(_bytes, 1, byte0 - LIST_LONG), uint256)


@internal
def _verify(
    _account_state_proof_rlp: Bytes[MAX_SIZE],
    _state_root: bytes32,
    _proof_path: bytes32
) -> Bytes[160]:
    # decode nibbles
    nibbles: uint256[64] = empty(uint256[64])
    for i in range(1, 65):
        nibbles[i - 1] = bitwise_and(shift(convert(_proof_path, uint256), 256 - 4 * i), 15)
    # _account_state_proof_rlp = rlp.encode(list(map(rlp.decode, proof.accountProof)))
    # convert _account_state_proof_rlp into list of proofs
    # then iterate through each proof
    path_offset: uint256 = 0
    next_hash: bytes32 = _state_root

    return b""


@external
def process_storage_root(
    _account: address,
    _block_number: uint256,
    _block_header_rlp: Bytes[MAX_SIZE],
    _account_state_proof_rlp: Bytes[MAX_SIZE],
):
    block_hash: bytes32 = blockhash(_block_number)

    assert block_hash != EMPTY_BYTES32  # dev: blockhash not available
    assert len(_block_header_rlp) > 123  # dev: invalid block header
    assert block_hash == keccak256(_block_header_rlp)  # dev: invalid block header

    state_root: bytes32 = extract32(_block_header_rlp, 91)
    proof_path: bytes32 = keccak256(slice(convert(_account, bytes32), 12, 20))

    # [nonce, balance, storageHash, codehash]
    account_rlp: Bytes[160] = self._verify(_account_state_proof_rlp, state_root, proof_path)
    storage_root: bytes32 = extract32(account_rlp, 69)
