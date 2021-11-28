# @version 0.3.0
"""
@title Root Liquidity Gauge Factory
@license MIT
@author Curve Finance
"""


interface CRV20:
    def rate() -> uint256: view
    def start_epoch_time_write() -> uint256: nonpayable

interface RootLiquidityGauge:
    def initialize(_chain_id: uint256, _inflation_params: InflationParams): nonpayable


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

event InflationParamsUpdated:
    _timestamp: uint256
    _old_params: InflationParams
    _new_params: InflationParams

event TransferOwnership:
    _old_owner: address
    _new_owner: address

event UpdateImplementation:
    _old_implementation: address
    _new_implementation: address


struct InflationParams:
    rate: uint256
    start_time: uint256


CRV: constant(address) = 0xD533a949740bb3306d119CC777fa900bA034cd52
RATE_REDUCTION_TIME: constant(uint256) = 86400 * 365


get_bridger: public(HashMap[uint256, address])
get_implementation: public(address)

get_gauge: public(HashMap[uint256, address[MAX_UINT256]])
get_gauge_count: public(HashMap[uint256, uint256])

inflation_params: public(InflationParams)

owner: public(address)
future_owner: public(address)


@external
def __init__(_implementation: address):
    if _implementation != ZERO_ADDRESS:
        self.get_implementation = _implementation
        log UpdateImplementation(ZERO_ADDRESS, _implementation)

    inflation_params: InflationParams = InflationParams({
        rate: CRV20(CRV).rate(),
        start_time: CRV20(CRV).start_epoch_time_write()
    })

    self.inflation_params = inflation_params
    log InflationParamsUpdated(block.timestamp, empty(InflationParams), inflation_params)

    self.owner = msg.sender
    log TransferOwnership(ZERO_ADDRESS, msg.sender)


@internal
def _updated_inflation_params() -> InflationParams:
    inflation_params: InflationParams = self.inflation_params
    if block.timestamp >= inflation_params.start_time + RATE_REDUCTION_TIME:
        new_params: InflationParams = InflationParams({
            rate: CRV20(CRV).rate(),
            start_time: CRV20(CRV).start_epoch_time_write()
        })
        self.inflation_params = new_params
        log InflationParamsUpdated(block.timestamp, inflation_params, new_params)
        return new_params

    return inflation_params


@payable
@external
def deploy_gauge(_chain_id: uint256, _salt: bytes32) -> address:
    """
    @notice Deploy a root liquidity gauge
    @param _chain_id The chain identifier of the counterpart child gauge
    @param _salt A value to deterministically deploy a gauge
    """
    assert self.get_bridger[_chain_id] != ZERO_ADDRESS  # dev: chain id not supported

    implementation: address = self.get_implementation
    gauge: address = create_forwarder_to(
        implementation, value=msg.value, salt=keccak256(_abi_encode(_chain_id, msg.sender, _salt))
    )

    idx: uint256 = self.get_gauge_count[_chain_id]
    self.get_gauge[_chain_id][idx] = gauge
    self.get_gauge_count[_chain_id] = idx + 1

    RootLiquidityGauge(gauge).initialize(_chain_id, self._updated_inflation_params())

    log DeployedGauge(implementation, _chain_id, msg.sender, _salt, gauge)
    return gauge


@external
def inflation_params_write() -> InflationParams:
    """
    @notice Query the inflation params and update them if necessary
    """
    return self._updated_inflation_params()


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
