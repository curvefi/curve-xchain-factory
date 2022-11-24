# @version 0.3.7
"""
@title InsureDAO Celer cBridge Wrapper
"""
from vyper.interfaces import ERC20


interface OriginalTokenVaultV2:
    def deposit(_token: address, _amount: uint256, _mintChainId: uint64, _mintAccount: address, _nonce: uint64) -> Bytes[32]: nonpayable


INSURE: constant(address) = 0xD533a949740bb3306d119CC777fa900bA034cd52
ORIGINAL_TOKEN_VALUT_V2: constant(address) = 0x7510792A3B1969F9307F3845CE88e39578f2bAE1

mint_chain_id: public(immutable(uint64))


@external
def __init__(_mint_chain_id: uint64):
    # you must set the destination chain id
    mint_chain_id = _mint_chain_id
    assert ERC20(INSURE).approve(ORIGINAL_TOKEN_VALUT_V2, max_value(uint256))


@external
def bridge(_token: address, _to: address, _amount: uint256):
    """
    @notice Bridge a token to a specified chain. You should list token on Celer before bridge
    @param _token The token to bridge
    @param _to The address to deposit the token to on specified chain
    @param _amount The amount of the token to bridge
    """
    assert _token == INSURE
    assert _to == msg.sender
    assert ERC20(_token).transferFrom(msg.sender, self, _amount)

    _nonce: uint64 = convert(block.timestamp, uint64)

    OriginalTokenVaultV2(ORIGINAL_TOKEN_VALUT_V2).deposit(
        _token,
        _amount,
        mint_chain_id,
        _to,
        _nonce
    )


@pure
@external
def cost() -> uint256:
    """
    @notice Cost in ETH to bridge
    """
    return 0


@pure
@external
def check(_account: address) -> bool:
    """
    @notice Check if `_account` is allowed to bridge
    @param _account The account to check
    """
    return True
