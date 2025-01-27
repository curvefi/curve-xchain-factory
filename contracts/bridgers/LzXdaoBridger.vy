# @version 0.4.0
"""
@title LzXdaoBridger
@custom:version 0.0.1
@author Curve.Fi
@license Copyright (c) Curve.Fi, 2020-2024 - all rights reserved
@notice Curve Xdao Layer Zero bridge wrapper
"""

version: public(constant(String[8])) = "0.0.1"

from ethereum.ercs import IERC20
import IBridger

implements: IBridger


interface Bridge:
    def bridge(_receiver: address, _amount: uint256, _refund: address): payable
    def quote() -> uint256: view


CRV20: constant(address) = 0xD533a949740bb3306d119CC777fa900bA034cd52
BRIDGE: public(immutable(Bridge))

DESTINATION_CHAIN_ID: public(immutable(uint256))


@deploy
def __init__(_bridge: Bridge, _chain_id: uint256):
    """
    @param _bridge Layer Zero Bridge of CRV
    @param _chain_id Chain ID to bridge to (actual, not LZ)
    """
    BRIDGE = _bridge
    DESTINATION_CHAIN_ID = _chain_id

    assert extcall IERC20(CRV20).approve(BRIDGE.address, max_value(uint256))


@external
@payable
def bridge(_token: IERC20, _to: address, _amount: uint256, _min_amount: uint256=0) -> uint256:
    """
    @notice Bridge `_token` through XDAO Layer Zero
    @param _token The ERC20 asset to bridge
    @param _to The receiver on `_chain_id`
    @param _amount The amount of `_token` to deposit, 2^256-1 for the whole balance
    @param _min_amount Minimum amount when to bridge
    @return Bridged amount
    """
    amount: uint256 = _amount
    if amount == max_value(uint256):
        amount = min(staticcall _token.balanceOf(msg.sender), staticcall _token.allowance(msg.sender, self))
    assert amount >= _min_amount, "Amount too small"

    assert extcall _token.transferFrom(msg.sender, self, amount)

    extcall BRIDGE.bridge(_to, amount, msg.sender, value=self.balance)
    return amount


@view
@external
def cost() -> uint256:
    """
    @notice Cost in ETH to bridge
    """
    return staticcall BRIDGE.quote()


@view
@external
def check(_account: address) -> bool:
    """
    @notice Check if `_account` is allowed to bridge
    @param _account The account to check
    """
    return True
