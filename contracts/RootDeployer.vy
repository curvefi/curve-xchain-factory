# @version 0.3.1
"""
@title Root Chain Gauge Deployer
@license MIT
@author Curve Finance
"""


interface Factory:
    def deploy_gauge(_chain_id: uint256, _salt: bytes32) -> address: nonpayable


ANYCALL: immutable(address)
FACTORY: immutable(address)


salt: public(bytes32)


@external
def __init__(_anycall: address, _factory: address):
    ANYCALL = _anycall
    FACTORY = _factory


@external
def deploy_gauge(_chain_id: uint256, _lp_token: address, _manager: address = msg.sender):
    """
    @notice Deploy a cross chain gauge, and send a cross chain call to deploy the child gauge as well
    @param _chain_id The chain to deploy the gauge for
    @param _lp_token The lp token of the pool on the child chain to deploy the gauge for
    @param _manager The address which will manager external rewards for the child gauge
    """
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
            convert(1, uint256),  # 17
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