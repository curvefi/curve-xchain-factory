# @version 0.3.1
"""
@title Child Liquidity Gauge Factory
@license MIT
@author Curve Finance
"""


interface ChildLiquidityGauge:
    def initialize(_lp_token: address, _manager: address): nonpayable


event DeployedGauge:
    _implementation: indexed(address)
    _lp_token: indexed(address)
    _deployer: indexed(address)
    _salt: bytes32
    _gauge: address

event UpdateImplementation:
    _old_implementation: address
    _new_implementation: address

event UpdateVotingEscrow:
    _old_voting_escrow: address
    _new_voting_escrow: address

event ManagerUpdated:
    _old_manager: address
    _new_manager: address

event UpdatePermission:
    _addr: indexed(address)
    _permitted: bool

event TransferOwnership:
    _old_owner: address
    _new_owner: address


ANYCALL: immutable(address)


get_implementation: public(address)
voting_escrow: public(address)

owner: public(address)
future_owner: public(address)
manager: public(address)

permitted: public(HashMap[address, bool])
is_valid_gauge: public(HashMap[address, bool])
get_gauge_from_lp_token: public(HashMap[address, address])
get_gauge_count: public(uint256)
get_gauge: public(address[MAX_INT128])


@external
def __init__(_anycall: address, _owner: address):
    ANYCALL = _anycall

    self.owner = _owner
    self.manager = _owner
    log ManagerUpdated(ZERO_ADDRESS, _owner)
    log TransferOwnership(ZERO_ADDRESS, _owner)


@external
def request_emissions():
    """
    @notice Request emissions for a deployed gauge
    @dev Caller must be a permitted gauge
    """
    if not self.permitted[msg.sender]:
        return

    # arrange data as an array in memory
    data: uint256[2] = [
        convert(method_id("transmit_emissions(address)", output_type=bytes32), uint256),
        convert(msg.sender, uint256)
    ]

    # shift elements of the array to form an abi-encoded payload
    array: uint256[2] = [
        bitwise_or(shift(data[0], 224), shift(data[1], -32)),
        shift(data[1], 224)
    ]

    # send the request cross-chain
    raw_call(
        ANYCALL,
        _abi_encode(
            convert(160, uint256),  # address[] - 0
            convert(224, uint256),  # bytes[] - 1
            convert(384, uint256),  # address[] - 2
            convert(416, uint256),  # uint256[] - 3
            convert(1, uint256),  # uint256 - 4
            convert(1, uint256),  # number of address elements - 5
            self,  # 6
            convert(1, uint256),  # number of bytes elements - 7
            convert(32, uint256),  # bytes start pos - 8
            convert(36, uint256),  # length in bytes - 9
            array,  # bytes right padded - 10/11
            convert(0, uint256),  # number of address elements - 12
            convert(0, uint256),  # number of uint256 elements - 13
            method_id=method_id("anyCall(address[],bytes[],address[],uint256[],uint256)"),
        )
    )


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
    self.is_valid_gauge[gauge] = True

    ChildLiquidityGauge(gauge).initialize(_lp_token, _manager)

    log DeployedGauge(implementation, _lp_token, msg.sender, _salt, gauge)
    return gauge


@external
def set_permitted(_gauge: address, _permit: bool):
    """
    @notice Set permission of a gauge to make a cross chain call
    """
    assert msg.sender == self.manager  # dev: only manager

    self.permitted[_gauge] = _permit
    log UpdatePermission(_gauge, _permit)


@external
def set_manager(_manager: address):
    """
    @notice Update the manager address
    """
    assert msg.sender == self.owner

    log ManagerUpdated(self.manager, _manager)
    self.manager = _manager


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
