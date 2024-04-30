# @version 0.3.10
"""
@title Curve Polygon zkEVM Bridge Wrapper
"""
from vyper.interfaces import ERC20


CRV20: constant(address) = 0xD533a949740bb3306d119CC777fa900bA034cd52
L1_BRIDGE: immutable(address)

DESTINATION_NETWORK: immutable(uint32)


@external
def __init__(_l1_bridge: address, _network: uint32):
    L1_BRIDGE = _l1_bridge
    assert ERC20(CRV20).approve(_l1_bridge, max_value(uint256))

    DESTINATION_NETWORK = _network


@external
def bridge(_token: ERC20, _to: address, _amount: uint256):
    """
    @notice Bridge a token to Polygon zkEVM using built-in PolygonZkEVMBridge
    @param _token The token to bridge
    @param _to The address to deposit the token to on L2
    @param _amount The amount of the token to deposit
    """
    assert _token.transferFrom(msg.sender, self, _amount)

    if _token.allowance(self, L1_BRIDGE) < _amount:
        _token.approve(L1_BRIDGE, max_value(uint256))

    raw_call(
        L1_BRIDGE,
        _abi_encode(
            DESTINATION_NETWORK,
            _to,
            _amount,
            _token.address,
            False,
            b"",
            method_id=method_id("bridgeAsset(uint32,address,uint256,address,bool,bytes")
        )
    )


@view
@external
def check(_account: address) -> bool:
    """
    @notice Dummy method to check if caller is allowed to bridge
    @param _account The account to check
    """
    return True


@view
@external
def cost() -> uint256:
    """
    @notice Cost in ETH to bridge
    """
    return 0
