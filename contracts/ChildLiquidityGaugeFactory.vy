# @version 0.3.0
"""
@title Child Liquidity Gauge Factory
@license MIT
@author Curve Finance
"""


interface ChildLiquidityGauge:
    def initialize(
        _lp_token: address, _manager: address, _inflation_params: InflationParams
    ): nonpayable


event DeployedGauge:
    _implementation: indexed(address)
    _lp_token: indexed(address)
    _deployer: indexed(address)
    _salt: bytes32
    _gauge: address

event InflationParamsUpdated:
    _timestamp: uint256
    _old_params: InflationParams
    _new_params: InflationParams

event UpdateImplementation:
    _old_implementation: address
    _new_implementation: address

event UpdateVotingEscrow:
    _old_voting_escrow: address
    _new_voting_escrow: address

event TransferOwnership:
    _old_owner: address
    _new_owner: address


struct InflationParams:
    rate: uint256
    finish_time: uint256


YEAR: constant(uint256) = 86400 * 365
RATE_DENOMINATOR: constant(uint256) = 10 ** 18
RATE_REDUCTION_COEFFICIENT: constant(uint256) = 1189207115002721024  # 2 ** (1/4) * 1e18
RATE_REDUCTION_TIME: constant(uint256) = YEAR


get_implementation: public(address)

inflation_params: public(InflationParams)
voting_escrow: public(address)

owner: public(address)
future_owner: public(address)

get_gauge_from_lp_token: public(HashMap[address, address])
get_gauge_count: public(uint256)
get_gauge: public(address[MAX_INT128])


@external
def __init__(_implementation: address, _inflation_params: InflationParams):
    if _implementation != ZERO_ADDRESS:
        self.get_implementation = _implementation
        log UpdateImplementation(ZERO_ADDRESS, _implementation)

    assert _inflation_params.finish_time - YEAR <= block.timestamp
    assert block.timestamp < _inflation_params.finish_time

    self.inflation_params = _inflation_params
    log InflationParamsUpdated(block.timestamp, empty(InflationParams), _inflation_params)

    self.owner = msg.sender
    log TransferOwnership(ZERO_ADDRESS, msg.sender)


@internal
def _updated_inflation_params() -> InflationParams:
    inflation_params: InflationParams = self.inflation_params
    if block.timestamp >= inflation_params.finish_time:
        new_params: InflationParams = InflationParams({
            rate: inflation_params.rate * RATE_DENOMINATOR / RATE_REDUCTION_COEFFICIENT,
            finish_time: inflation_params.finish_time + RATE_REDUCTION_TIME
        })
        self.inflation_params = new_params
        log InflationParamsUpdated(block.timestamp, inflation_params, new_params)
        return new_params

    return inflation_params


@external
def deploy_gauge(_lp_token: address, _salt: bytes32, _manager: address = msg.sender) -> address:
    """
    @notice Deploy a liquidity gauge
    @param _lp_token The token to deposit in the gauge
    @param _manager The address to set as manager of the gauge
    @param _salt A value to deterministically deploy a gauge
    """
    if self.get_gauge_from_lp_token[_lp_token] != ZERO_ADDRESS:
        # overwriting lp_token -> gauge mapping requires
        assert msg.sender == self.owner  # dev: only owner

    implementation: address = self.get_implementation
    gauge: address = create_forwarder_to(
        implementation, salt=keccak256(_abi_encode(chain.id, msg.sender, _salt))
    )

    idx: uint256 = self.get_gauge_count
    self.get_gauge[idx] = gauge
    self.get_gauge_count = idx + 1
    self.get_gauge_from_lp_token[_lp_token] = gauge

    ChildLiquidityGauge(gauge).initialize(_lp_token, _manager, self._updated_inflation_params())

    log DeployedGauge(implementation, _lp_token, msg.sender, _salt, gauge)
    return gauge


@external
def inflation_params_write() -> InflationParams:
    """
    @notice Query the inflation params and update them if necessary
    """
    return self._updated_inflation_params()


@external
def set_voting_escrow(_voting_escrow: address):
    """
    @notice Update the voting escrow contract
    @param _voting_escrow Contract to use as the voting escrow oracle
    """
    assert msg.sender == self.owner  # dev: only owner

    log UpdateVotingEscrow(self.voting_escrow, _voting_escrow)
    self.voting_escrow = _voting_escrow


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
