# @version 0.3.10
"""
@title Curve Polygon zkEVM Bridge Wrapper
"""
from vyper.interfaces import ERC20


interface PolygonZkEVMBridge:
    def bridgeAsset(destination_network: uint32, destination_address: address, amount: uint256, token: address, force_update: bool, permit_data: Bytes[2]): nonpayable


CRV20: constant(address) = 0xD533a949740bb3306d119CC777fa900bA034cd52
L1_BRIDGE: immutable(PolygonZkEVMBridge)

DESTINATION_NETWORK: immutable(uint32)


@external
def __init__(_l1_bridge: PolygonZkEVMBridge, _network: uint32):
    L1_BRIDGE = _l1_bridge
    assert ERC20(CRV20).approve(_l1_bridge.address, max_value(uint256))

    DESTINATION_NETWORK = _network


@external
def bridge(_token: ERC20, _to: address, _amount: uint256):
    """
    @notice Bridge a token to Polygon zkEVM using built-in PolygonZkEVMBridge
    @dev Might need `claimAsset` on destination chain, save `depositCount` from POLYGON_ZKEVM_BRIDGE.BridgeEvent
    @param _token The token to bridge
    @param _to The address to deposit the token to on L2
    @param _amount The amount of the token to deposit
    """
    assert _token.transferFrom(msg.sender, self, _amount)

    if _token.allowance(self, L1_BRIDGE.address) < _amount:
        _token.approve(L1_BRIDGE.address, max_value(uint256))

    L1_BRIDGE.bridgeAsset(DESTINATION_NETWORK, _to, _amount, _token.address, True, b"")


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
