# @version 0.3.1
"""
@notice Simple Root veCRV Oracle
"""
from vyper.interfaces import ERC20


interface Factory:
    def get_bridger(_chain_id: uint256) -> address: view

interface VotingEscrow:
    def epoch() -> uint256: view
    def point_history(_idx: uint256) -> Point: view
    def user_point_epoch(_user: address) -> uint256: view
    def user_point_history(_user: address, _idx: uint256) -> Point: view


struct Point:
    bias: int128
    slope: int128
    ts: uint256


# keccak256('receive((int128,int128,uint256),(int128,int128,uint256),address)')[:4] << 224
SELECTOR: constant(uint256) = 77616072821038823001602706230675513323446629588489185852212582413108617674752


FACTORY: immutable(address)
VE: immutable(address)
CALL_PROXY: immutable(address)


@external
def __init__(_factory: address, _ve: address, _call_proxy: address):
    FACTORY = _factory
    VE = _ve
    CALL_PROXY = _call_proxy


@external
def push(_chain_id: uint256, _user: address = msg.sender):
    assert Factory(FACTORY).get_bridger(_chain_id) != ZERO_ADDRESS  # dev: invalid chain

    ve: address = VE
    assert ERC20(ve).balanceOf(_user) != 0

    user_point: Point = VotingEscrow(ve).user_point_history(
        _user, VotingEscrow(ve).user_point_epoch(_user)
    )
    global_point: Point = VotingEscrow(ve).point_history(VotingEscrow(ve).epoch())

    data: uint256[8] = [
        SELECTOR + shift(convert(user_point.bias, uint256), -32),
        shift(convert(user_point.bias, uint256), 224) + shift(convert(user_point.slope, uint256), -32),
        shift(convert(user_point.slope, uint256), 224) + shift(user_point.ts, -32),
        shift(user_point.ts, 224) + shift(convert(global_point.bias, uint256), -32),
        shift(convert(global_point.bias, uint256), 224) + shift(convert(global_point.slope, uint256), -32),
        shift(convert(global_point.slope, uint256), 224) + shift(global_point.ts, -32),
        shift(global_point.ts, 224) + shift(convert(_user, uint256), -32),
        shift(convert(_user, uint256), 224),
    ]

    raw_call(
        CALL_PROXY,
        _abi_encode(
            convert(160, uint256),  # address[] - 0
            convert(224, uint256),  # bytes[] - 1
            convert(576, uint256),  # address[] - 2
            convert(608, uint256),  # uint256[] - 3
            _chain_id,  # uint256 - 4
            convert(1, uint256),  # number of address elements - 5
            self,  # 6
            convert(1, uint256),  # number of bytes elements - 7
            convert(32, uint256),  # bytes start pos - 8
            convert(228, uint256),  # length in bytes - 9
            data,  # bytes right padded - 10/11/12/13/14/15/16/17
            convert(0, uint256),  # number of address elements - 18
            convert(0, uint256),  # number of address elements - 19
            method_id=method_id("anyCall(address[],bytes[],address[],uint256[],uint256)"),
        )
    )
