# @version 0.3.1
"""
@title Simple Child veOracle
"""


struct Point:
    bias: int128
    slope: int128
    ts: uint256


CALL_PROXY: immutable(address)


user_points: public(HashMap[address, Point])
global_point: public(Point)


@external
def __init__(_call_proxy: address):
    CALL_PROXY = _call_proxy


@view
@external
def balanceOf(_user: address) -> uint256:
    last_point: Point = self.user_points[_user]
    last_point.bias -= last_point.slope * convert(block.timestamp - last_point.ts, int128)
    if last_point.bias < 0:
        last_point.bias = 0
    return convert(last_point.bias, uint256)


@view
@external
def totalSupply() -> uint256:
    last_point: Point = self.global_point
    last_point.bias -= last_point.slope * convert(block.timestamp - last_point.ts, int128)
    if last_point.bias < 0:
        last_point.bias = 0
    return convert(last_point.bias, uint256)


@external
def receive(_user_point: Point, _global_point: Point, _user: address):
    assert msg.sender == CALL_PROXY

    prev_user_point: Point = self.user_points[_user]
    if _user_point.ts > prev_user_point.ts:
        self.user_points[_user] = _user_point

    prev_global_point: Point = self.global_point
    if _global_point.ts > prev_global_point.ts:
        self.global_point = _global_point
