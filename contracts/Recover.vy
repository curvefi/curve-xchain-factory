# @version 0.3.1


@pure
@external
def recover(_sighash: bytes32, _v: uint8, _r: uint256, _s: uint256) -> address:
    # this can return ZERO_ADDRESS
    return ecrecover(_sighash, convert(_v, uint256), _r, _s)
