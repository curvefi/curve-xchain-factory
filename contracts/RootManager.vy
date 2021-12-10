# @version 0.3.1
"""
@title Root Chain Gauge Deployer
@license MIT
@author Curve Finance
"""
from vyper.interfaces import ERC20


interface AnyCall:
    def encode(_sig: String[256], _data: Bytes[512]) -> ByteArray: pure

interface Factory:
    def deploy_gauge(_chain_id: uint256, _salt: bytes32) -> address: nonpayable
    def get_bridger(_chain_id: uint256) -> address: view

interface VotingEscrow:
    def locked__end(_user: address) -> uint256: view


struct ByteArray:
    position: uint256
    length: uint256
    data: uint256[6]


ANYCALL: immutable(address)
FACTORY: immutable(address)
VOTING_ESCROW: immutable(address)


salt: public(bytes32)


@external
def __init__(_anycall: address, _factory: address, _voting_escrow: address):
    ANYCALL = _anycall
    FACTORY = _factory
    VOTING_ESCROW = _voting_escrow


@external
def push_ve_data(_chain_id: uint256, _user: address):
    """
    @notice Push veCRV data for `_user` to `_chain_id`
    @param _chain_id The target chain
    @param _user The user to push data for
    """
    assert msg.sender == tx.origin
    assert Factory(FACTORY).get_bridger(_chain_id) != ZERO_ADDRESS

    user_balance: uint256 = ERC20(VOTING_ESCROW).balanceOf(_user)
    lock_end: uint256 = VotingEscrow(VOTING_ESCROW).locked__end(_user)
    total_supply: uint256 = ERC20(VOTING_ESCROW).totalSupply()

    array: uint256[6] = AnyCall(ANYCALL).encode(
        "receive_ve_data(address,uint256,uint256,uint256,uint256)",
        _abi_encode(_user, user_balance, lock_end, total_supply, block.timestamp)
    ).data

    # send the request cross-chain
    raw_call(
        ANYCALL,
        _abi_encode(
            convert(160, uint256),  # address[] - 0
            convert(224, uint256),  # bytes[] - 1
            convert(512, uint256),  # address[] - 2
            convert(544, uint256),  # uint256[] - 3
            _chain_id,  # uint256 - 4
            convert(1, uint256),  # number of address elements - 5
            self,  # 6
            convert(1, uint256),  # number of bytes elements - 7
            convert(32, uint256),  # bytes start pos - 8
            convert(164, uint256),  # length in bytes - 9
            array,  # bytes right padded - 10/11/12/13/14/15
            convert(0, uint256),  # number of address elements - 16
            convert(0, uint256),  # number of uint256 elements - 17
            method_id=method_id("anyCall(address[],bytes[],address[],uint256[],uint256)"),
        )
    )



@external
def deploy_gauge(_chain_id: uint256, _lp_token: address, _manager: address = msg.sender):
    """
    @notice Deploy a cross chain gauge, and send a cross chain call to deploy the child gauge as well
    @param _chain_id The chain to deploy the gauge for
    @param _lp_token The lp token of the pool on the child chain to deploy the gauge for
    @param _manager The address which will manager external rewards for the child gauge
    """
    assert msg.sender == tx.origin
    assert Factory(FACTORY).get_bridger(_chain_id) != ZERO_ADDRESS

    salt: bytes32 = self.salt
    self.salt = keccak256(salt)

    data: uint256[4] = [
        convert(method_id("deploy_gauge(address,bytes32,address)", output_type=bytes32), uint256),
        convert(_lp_token, uint256),
        convert(salt, uint256),
        convert(_manager, uint256),
    ]

    array: uint256[4] = [
        bitwise_or(shift(data[0], 224), shift(data[1], -32)),
        bitwise_or(shift(data[1], 224), shift(data[2], -32)),
        bitwise_or(shift(data[2], 224), shift(data[3], -32)),
        shift(data[3], 224)
    ]

    # send the request cross-chain
    raw_call(
        ANYCALL,
        _abi_encode(
            convert(160, uint256),  # address[] - 0
            convert(224, uint256),  # bytes[] - 1
            convert(448, uint256),  # address[] - 2
            convert(512, uint256),  # uint256[] - 3
            _chain_id,  # uint256 - 4
            convert(1, uint256),  # number of address elements - 5
            self,  # 6
            convert(1, uint256),  # number of bytes elements - 7
            convert(32, uint256),  # bytes start pos - 8
            convert(100, uint256),  # length in bytes - 9
            array,  # bytes right padded - 10/11/12/13
            convert(1, uint256),  # number of address elements - 14
            self,  # 15
            convert(1, uint256),  # number of uint256 elements - 16
            convert(0, uint256),  # 17
            method_id=method_id("anyCall(address[],bytes[],address[],uint256[],uint256)"),
        )
    )


@external
def callback(
    _to: address,
    _data: Bytes[2048],
    _nonces: uint256,
    _from_chain_id: uint256,
    _success: bool,
    _result: Bytes[2048]
):
    assert msg.sender == ANYCALL
    assert _success

    # _result == (_chain_id: uint256, _salt: bytes32, _gauge: address)
    gauge: address = Factory(FACTORY).deploy_gauge(convert(extract32(_result, 0), uint256), extract32(_result, 32))
    assert gauge == extract32(_result, 64, output_type=address)
