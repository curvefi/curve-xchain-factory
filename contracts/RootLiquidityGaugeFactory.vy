# @version 0.3.0
"""
@title Root Liquidity Gauge Factory
@license MIT
@author Curve Finance
"""


interface RootLiquidityGauge:
    def initialize(_chain_id: uint256): nonpayable


event BridgerUpdated:
    _chain_id: indexed(uint256)
    _old_bridger: address
    _new_bridger: address

event DeployedGauge:
    _implementation: indexed(address)
    _chain_id: indexed(uint256)
    _deployer: indexed(address)
    _salt: bytes32
    _gauge: address

event TransferOwnership:
    _old_owner: address
    _new_owner: address

event UpdateImplementation:
    _old_implementation: address
    _new_implementation: address


get_bridger: public(HashMap[uint256, address])
get_implementation: public(address)

get_gauge: public(HashMap[uint256, address[MAX_UINT256]])
get_gauge_count: public(HashMap[uint256, uint256])

owner: public(address)
future_owner: public(address)


@external
def __init__(_implementation: address):
    if _implementation != ZERO_ADDRESS:
        self.get_implementation = _implementation
        log UpdateImplementation(ZERO_ADDRESS, _implementation)

    self.owner = msg.sender
    log TransferOwnership(ZERO_ADDRESS, msg.sender)


@payable
@external
def deploy_gauge(_chain_id: uint256, _salt: bytes32) -> address:
    """
    @notice Deploy a root liquidity gauge
    @param _chain_id The chain identifier of the counterpart child gauge
    @param _salt A value to deterministically deploy a gauge
    """
    assert self.get_bridger[_chain_id] != ZERO_ADDRESS

    implementation: address = self.get_implementation
    gauge: address = create_forwarder_to(
        implementation, value=msg.value, salt=keccak256(_abi_encode(_chain_id, msg.sender, _salt))
    )

    idx: uint256 = self.get_gauge_count[_chain_id]
    self.get_gauge[_chain_id][idx] = gauge
    self.get_gauge_count[_chain_id] = idx + 1

    RootLiquidityGauge(gauge).initialize(_chain_id)

    log DeployedGauge(implementation, _chain_id, msg.sender, _salt, gauge)
    return gauge


@external
def set_bridger(_chain_id: uint256, _bridger: address):
    """
    @notice Set the bridger for `_chain_id`
    @param _chain_id The chain identifier to set the bridger for
    @param _bridger The bridger contract to use
    """
    assert msg.sender == self.owner

    log BridgerUpdated(_chain_id, self.get_bridger[_chain_id], _bridger)
    self.get_bridger[_chain_id] = _bridger


@external
def set_implementation(_implementation: address):
    """
    @notice Set the implementation
    @param _implementation The address of the implementation to use
    """
    assert msg.sender == self.owner

    log UpdateImplementation(self.get_implementation, _implementation)
    self.get_implementation = _implementation


@external
def commit_transfer_ownership(_future_owner: address):
    """
    @notice Transfer ownership to `_future_owner`
    @param _future_owner The account to commit as the future owner
    """
    assert msg.sender == self.owner  # dev: only owner

    self.future_owner = _future_owner


@external
def accept_transfer_ownership():
    """
    @notice Accept the transfer of ownership
    @dev Only the committed future owner can call this function
    """
    assert msg.sender == self.future_owner  # dev: only future owner

    log TransferOwnership(self.owner, msg.sender)
    self.owner = msg.sender
