# @version 0.3.1
"""
@title Child Liquidity Gauge Factory
@license MIT
@author Curve Finance
"""


interface ChildGauge:
    def initialize(_lp_token: address, _manager: address): nonpayable
    def integrate_fraction(_user: address) -> uint256: view
    def user_checkpoint(_user: address) -> bool: nonpayable


event DeployedGauge:
    _implementation: indexed(address)
    _lp_token: indexed(address)
    _deployer: indexed(address)
    _salt: bytes32
    _gauge: address

event Minted:
    _user: indexed(address)
    _gauge: indexed(address)
    _new_total: uint256

event UpdateImplementation:
    _old_implementation: address
    _new_implementation: address

event UpdateVotingEscrow:
    _old_voting_escrow: address
    _new_voting_escrow: address

event TransferOwnership:
    _old_owner: address
    _new_owner: address


# uint256(method_id("transmit_emissions(address)", output_type=bytes32)) << 224
SELECTOR: constant(uint256) = 8028065356917769638552618317072897550801200731460208786748395414364255944704
# uint256(method_id("deploy_gauge(uint256,bytes32)", output_type=bytes32)) << 224
DEPLOY_GAUGE_SELECTOR: constant(uint256) = 101788216200932537375414814801159281802993345172636369673355283355065034735616
WEEK: constant(uint256) = 86400 * 7


CALL_PROXY: immutable(address)
CRV: immutable(address)


get_implementation: public(address)
voting_escrow: public(address)

owner: public(address)
future_owner: public(address)

# [last_request][has_counterpart][is_valid_gauge]
gauge_data: public(HashMap[address, uint256])
# user -> gauge -> value
minted: public(HashMap[address, HashMap[address, uint256]])

get_gauge_from_lp_token: public(HashMap[address, address])
get_gauge_count: public(uint256)
get_gauge: public(address[MAX_INT128])


@external
def __init__(_call_proxy: address, _crv: address, _owner: address):
    CALL_PROXY = _call_proxy
    CRV = _crv

    self.owner = _owner
    log TransferOwnership(ZERO_ADDRESS, _owner)


@internal
def _psuedo_mint(_gauge: address, _user: address):
    gauge_data: uint256 = self.gauge_data[_gauge]
    assert gauge_data != 0  # dev: invalid gauge

    # if is_mirrored and last_request != this week
    if bitwise_and(gauge_data, 2) != 0 and shift(gauge_data, -2) / WEEK != block.timestamp / WEEK:
        data: uint256[2] = [
            SELECTOR + shift(convert(_gauge, uint256), -32),
            shift(convert(_gauge, uint256), 224)
        ]

        raw_call(
            CALL_PROXY,
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
                data,  # bytes right padded - 10/11
                convert(0, uint256),  # number of address elements - 12
                convert(0, uint256),  # number of uint256 elements - 13
                method_id=method_id("anyCall(address[],bytes[],address[],uint256[],uint256)"),
            )
        )
        # update last request time
        self.gauge_data[_gauge] = shift(block.timestamp, 2) + 3

    assert ChildGauge(_gauge).user_checkpoint(_user)
    total_mint: uint256 = ChildGauge(_gauge).integrate_fraction(_user)
    to_mint: uint256 = total_mint - self.minted[_user][_gauge]

    if to_mint != 0:
        # transfer tokens to user
        response: Bytes[32] = raw_call(
            CRV,
            _abi_encode(_user, to_mint, method_id=method_id("transfer(address,uint256)")),
            max_outsize=32,
        )
        if len(response) != 0:
            assert convert(response, bool)
        self.minted[_user][_gauge] = total_mint

        log Minted(_user, _gauge, total_mint)


@external
@nonreentrant("lock")
def mint(_gauge: address):
    """
    @notice Mint everything which belongs to `msg.sender` and send to them
    @param _gauge `LiquidityGauge` address to get mintable amount from
    """
    self._psuedo_mint(_gauge, msg.sender)


@external
@nonreentrant("lock")
def mint_many(_gauges: address[32]):
    """
    @notice Mint everything which belongs to `msg.sender` across multiple gauges
    @param _gauges List of `LiquidityGauge` addresses
    """
    for i in range(32):
        if _gauges[i] == ZERO_ADDRESS:
            pass
        self._psuedo_mint(_gauges[i], msg.sender)


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

    gauge_data: uint256 = 1  # set is_valid_gauge = True
    if msg.sender == CALL_PROXY:
        # issue a call to the root chain to deploy a gauge
        gauge_data += 2  # set mirrored = True
        data: uint256[3] = [
            DEPLOY_GAUGE_SELECTOR + shift(chain.id, -32),
            shift(chain.id, 224) + shift(convert(_salt, uint256), -32),
            shift(convert(_salt, uint256), 224)
        ]
        # send cross chain call to deploy gauge
        raw_call(
            CALL_PROXY,
            _abi_encode(
                convert(160, uint256),  # address[] - 0
                convert(224, uint256),  # bytes[] - 1
                convert(416, uint256),  # address[] - 2
                convert(448, uint256),  # uint256[] - 3
                convert(1, uint256),  # uint256 - 4
                convert(1, uint256),  # number of address elements - 5
                self,  # 6
                convert(1, uint256),  # number of bytes elements - 7
                convert(32, uint256),  # bytes start pos - 8
                convert(68, uint256),  # length in bytes - 9
                data,  # bytes right padded - 10/11/12
                convert(0, uint256),  # number of address elements - 13
                convert(0, uint256),  # number of uint256 elements - 14
                method_id=method_id("anyCall(address[],bytes[],address[],uint256[],uint256)"),
            )
        )

    implementation: address = self.get_implementation
    gauge: address = create_forwarder_to(
        implementation, salt=keccak256(_abi_encode(chain.id, msg.sender, _salt))
    )

    self.gauge_data[gauge] = gauge_data

    idx: uint256 = self.get_gauge_count
    self.get_gauge[idx] = gauge
    self.get_gauge_count = idx + 1
    self.get_gauge_from_lp_token[_lp_token] = gauge

    ChildGauge(gauge).initialize(_lp_token, _manager)

    log DeployedGauge(implementation, _lp_token, msg.sender, _salt, gauge)
    return gauge


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
def set_mirrored(_gauge: address, _mirrored: bool):
    """
    @notice Set the mirrored bit of the gauge data for `_gauge`
    @param _gauge The gauge of interest
    @param _mirrored Boolean deteremining whether to set the mirrored bit to True/False
    """
    gauge_data: uint256 = self.gauge_data[_gauge]
    assert gauge_data != 0  # dev: invalid gauge
    assert msg.sender == self.owner  # dev: only owner

    gauge_data = shift(shift(gauge_data, -2), 2) + 1  # set is_valid_gauge = True
    if _mirrored:
        gauge_data += 2  # set is_mirrored = True

    self.gauge_data[_gauge] = gauge_data


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


@view
@external
def is_valid_gauge(_gauge: address) -> bool:
    """
    @notice Query whether the gauge is a valid one deployed via the factory
    @param _gauge The address of the gauge of interest
    """
    return self.gauge_data[_gauge] != 0


@view
@external
def is_mirrored(_gauge: address) -> bool:
    """
    @notice Query whether the gauge is mirrored on Ethereum mainnet
    @param _gauge The address of the gauge of interest
    """
    return bitwise_and(self.gauge_data[_gauge], 2) != 0


@view
@external
def last_request(_gauge: address) -> uint256:
    """
    @notice Query the timestamp of the last cross chain request for emissions
    @param _gauge The address of the gauge of interest
    """
    return shift(self.gauge_data[_gauge], -2)
