# @version 0.3.1
"""
@notice Curve Multichain EOA Bridge Wrapper
"""
from vyper.interfaces import ERC20


event TransferOwnership:
    _old_owner: indexed(address)
    _new_owner: indexed(address)


ANYCALL: immutable(address)
ANYSWAP_BRIDGE: immutable(address)


minimum: public(HashMap[address, uint256])

owner: public(address)
future_owner: public(address)


@external
def __init__(_anycall: address, _anyswap_bridge: address):
    ANYCALL = _anycall
    ANYSWAP_BRIDGE = _anyswap_bridge

    self.owner = msg.sender
    log TransferOwnership(ZERO_ADDRESS, msg.sender)


@external
def bridge(_token: address, _to: address, _amount: uint256):
    """
    @notice Bridge an ERC20 using the multichain EOA bridge
    @dev Since the bridge uses `Transfer` events to determine
        the destination of the token, we use `transferFrom` to
        bridge the token from the caller to the bridge.
    @param _token A valid token for bridging with Multichain EOA bridge
    @param _to The address to send the token to on the sidechain
    @param _amount The amount to bridge
    """
    assert _to == msg.sender  # dev: invalid destination
    assert _amount >= self.minimum[_token]
    assert ERC20(_token).transferFrom(msg.sender, ANYSWAP_BRIDGE, _amount)


@external
def set_minimum(_token: address, _minimum: uint256):
    assert msg.sender == self.owner

    self.minimum[_token] = _minimum


@external
def commit_transfer_ownership(_future_owner: address):
    assert msg.sender == self.owner

    self.future_owner = _future_owner


@external
def accept_transfer_ownership():
    assert msg.sender == self.future_owner

    log TransferOwnership(self.owner, msg.sender)
    self.owner = msg.sender


@view
@external
def cost() -> uint256:
    """
    @notice Cost in ETH to bridge an ERC20 using the multichain bridge
    """
    return 0


@view
@external
def check(_transmit_caller: address) -> bool:
    """
    @notice Verify if `_transmit_caller` can bridge via the gauge factory
        `transmit_emissions` function
    @dev Multichain EOA bridges cannot handle multiple transfers in one call
        so we block smart contracts that could checkpoint multiple gauges at
        once. We also allow the AnyCallProxy to bridge since that means a
        request from cross chain has come through.
    @param _transmit_caller The address to verify
    """
    return _transmit_caller in [tx.origin, ANYCALL]


@pure
@external
def anycall() -> address:
    """
    @notice Query the address of the anycall call proxy
    """
    return ANYCALL


@pure
@external
def anyswap_bridge() -> address:
    """
    @notice Query the Multichain EOA bridge for this wrapper
    """
    return ANYSWAP_BRIDGE
