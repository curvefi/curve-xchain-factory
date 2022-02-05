# @version 0.3.1
"""
@notice Simple Root veCRV Oracle
"""
from vyper.interfaces import ERC20


interface CallProxy:
    def anyCall(
        _to: address, _data: Bytes[1024], _fallback: address, _to_chain_id: uint256
    ): nonpayable

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
    """
    @notice Push veCRV data to a child chain
    """
    assert Factory(FACTORY).get_bridger(_chain_id) != ZERO_ADDRESS  # dev: invalid chain

    ve: address = VE
    assert ERC20(ve).balanceOf(_user) != 0

    user_point: Point = VotingEscrow(ve).user_point_history(
        _user, VotingEscrow(ve).user_point_epoch(_user)
    )
    global_point: Point = VotingEscrow(ve).point_history(VotingEscrow(ve).epoch())

    CallProxy(CALL_PROXY).anyCall(
        self,
        _abi_encode(
            user_point,
            global_point,
            _user,
            method_id=method_id("receive((int128,int128,uint256),(int128,int128,uint256),address)")
        ),
        ZERO_ADDRESS,
        _chain_id
    )
