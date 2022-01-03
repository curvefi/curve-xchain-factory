# @version 0.3.1
"""
@title Root Liquidity Gauge Factory
@license MIT
@author Curve Finance
"""


interface RootLiquidityGauge:
    def initialize(_bridger: address, _chain_id: uint256): nonpayable
    def transmit_emissions(): nonpayable


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
is_valid_gauge: public(HashMap[address, bool])

owner: public(address)
future_owner: public(address)


@external
def __init__(_owner: address):
    self.owner = _owner
    log TransferOwnership(ZERO_ADDRESS, _owner)


@internal
def _deploy_gauge(
    _chain_id: uint256, _salt: bytes32, _msg_sender: address, _msg_value: uint256
) -> address:
    """
    @dev Internal method for deploying gauges
    """
    bridger: address = self.get_bridger[_chain_id]
    assert bridger != ZERO_ADDRESS  # dev: chain id not supported

    implementation: address = self.get_implementation
    gauge: address = create_forwarder_to(
        implementation,
        value=_msg_value,
        salt=keccak256(_abi_encode(_chain_id, _msg_sender, _salt))
    )

    idx: uint256 = self.get_gauge_count[_chain_id]
    self.get_gauge[_chain_id][idx] = gauge
    self.get_gauge_count[_chain_id] = idx + 1
    self.is_valid_gauge[gauge] = True

    RootLiquidityGauge(gauge).initialize(bridger, _chain_id)

    log DeployedGauge(implementation, _chain_id, _msg_sender, _salt, gauge)
    return gauge


@external
def transmit_emissions(_gauge: address):
    """
    @notice Call `transmit_emissions` on a root gauge
    @dev Entrypoint for anycall to request emissions for a child gauge.
        The way that gauges work, this can also be called on the root
        chain without a request.
    """
    RootLiquidityGauge(_gauge).transmit_emissions()


@payable
@external
def deploy_gauge(_chain_id: uint256, _salt: bytes32) -> address:
    """
    @notice Deploy a root liquidity gauge
    @param _chain_id The chain identifier of the counterpart child gauge
    @param _salt A value to deterministically deploy a gauge
    """
    return self._deploy_gauge(_chain_id, _salt, msg.sender, msg.value)


@external
def callback(
    _to: address,
    _data: Bytes[128],
    _nonces: uint256,
    _from_chain_id: uint256,
    _success: bool,
    _result: Bytes[32],
):
    """
    @notice Deploy a gauge automatically after successfully performing a cross chain call
    @param _to The target of the cross chain call performed via AnyswapV4CallProxy#anyCall
    @param _data The calldata supplied to perform a cross chain call
    @param _nonces The position of the callback in the list of callbacks
    @param _from_chain_id The chain id of the target cross chain call
    @param _success Whether call was successful
    @param _result The return data from the cross chain call
    """
    assert _to == self  # dev: invalid target
    assert slice(_data, 0, 4) == method_id("deploy_gauge(address,bytes32,address)")  # dev: invalid method
    assert _success  # dev: operation unsuccessful
    assert self._deploy_gauge(_from_chain_id, extract32(_data, 36), msg.sender, 0) == extract32(_result, 0, output_type=address)


@external
def set_bridger(_chain_id: uint256, _bridger: address):
    """
    @notice Set the bridger for `_chain_id`
    @param _chain_id The chain identifier to set the bridger for
    @param _bridger The bridger contract to use
    """
    assert msg.sender == self.owner  # dev: only owner

    log BridgerUpdated(_chain_id, self.get_bridger[_chain_id], _bridger)
    self.get_bridger[_chain_id] = _bridger


@external
def set_implementation(_implementation: address):
    """
    @notice Set the implementation
    @param _implementation The address of the implementation to use
    """
    assert msg.sender == self.owner  # dev: only owner

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
