# @version 0.3.1
"""
@title Child Chain Gauge Deployer
@license MIT
@author Curve Finance
"""


interface Factory:
    def deploy_gauge(_lp_token: address, _salt: bytes32, _manager: address) -> address: nonpayable

interface Minter:
    def set_has_counterpart(_gauge: address, _has_countepart: bool): nonpayable


event UpdateVEBalance:
    _user: indexed(address)
    _balance: uint256
    _timestamp: uint256

event UpdateVETotalSupply:
    _total_supply: uint256
    _timestamp: uint256


struct Point:
    bias: int256
    slope: int256


MAXTIME: constant(uint256) = 86400 * 4 * 365

ANYCALL: immutable(address)
FACTORY: immutable(address)
MINTER: immutable(address)


user_points: public(HashMap[address, Point])
point: public(Point)
last_update: public(uint256)


@external
def __init__(_anycall: address, _factory: address, _minter: address):
    ANYCALL = _anycall
    FACTORY = _factory
    MINTER = _minter


@view
@external
def balanceOf(_user: address) -> uint256:
    point: Point = self.user_points[_user]
    point.bias += point.slope * convert(block.timestamp, int256)

    if point.bias < 0:
        return 0
    return convert(point.bias, uint256)


@view
@external
def totalSupply() -> uint256:
    point: Point = self.point
    point.bias += point.slope * convert(block.timestamp, int256)

    if point.bias < 0:
        return 0
    return convert(point.bias, uint256)


@view
@external
def locked__end(_user: address) -> uint256:
    point: Point = self.user_points[_user]
    if point.bias == 0:
        return 0
    return convert(-point.bias / point.slope, uint256)


@external
def deploy_gauge(_lp_token: address, _salt: bytes32, _manager: address) -> (uint256, bytes32, address):
    """
    @notice Deploy the counter part child gauge for a root gauge
    @dev Also sets the gauge permission to True to enable it sending calls back
        to the root chain. Only callable by the anycall proxy
    @param _lp_token The lp token to deploy the gauge for
    @param _salt The salt value to use for the gauge
    @param _manager The manager of external rewards for the newly deployed gauge
    """
    assert msg.sender == ANYCALL

    gauge: address = Factory(FACTORY).deploy_gauge(_lp_token, _salt, _manager)
    Minter(MINTER).set_has_counterpart(gauge, True)
    return chain.id, _salt, gauge


@external
def receive_ve_data(
    _user: address,
    _balance: uint256,
    _lock_end: uint256,
    _total_supply: uint256,
    _timestamp: uint256
):
    """
    @notice Receive veCRV data about user and total supply
    @param _user The user to update data of
    @param _balance The balance of the user
    @param _lock_end The end of the user's lock
    @param _total_supply The total supply of veCRV
    @param _timestamp The L1 timestamp the data push occured at
    """
    assert msg.sender == ANYCALL

    if _balance != 0:
        user_point: Point = empty(Point)
        user_point.slope = -convert(_balance, int256) / convert(_lock_end - _timestamp, int256)
        user_point.bias = convert(_balance, int256) - user_point.slope * convert(_timestamp, int256)
        self.user_points[_user] = user_point
        log UpdateVEBalance(_user, _balance, _timestamp)

    if _timestamp > self.last_update:
        point: Point = empty(Point)
        point.slope = -convert(_total_supply, int256) / MAXTIME
        point.bias = convert(_total_supply, int256) - point.slope * convert(_timestamp, int256)
        self.last_update = _timestamp
        log UpdateVETotalSupply(_total_supply, _timestamp)
