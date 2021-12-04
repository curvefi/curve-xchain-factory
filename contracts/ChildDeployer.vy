# @version 0.3.1
"""
@title Child Chain Gauge Deployer
@license MIT
@author Curve Finance
"""


interface Factory:
    def deploy_gauge(_lp_token: address, _salt: bytes32, _manager: address) -> address: nonpayable
    def set_permitted(_gauge: address, _permission: bool): nonpayable


ANYCALL: immutable(address)
FACTORY: immutable(address)


@external
def __init__(_anycall: address, _factory: address):
    ANYCALL = _anycall
    FACTORY = _factory


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
    Factory(FACTORY).set_permitted(gauge, True)
    return chain.id, _salt, gauge
