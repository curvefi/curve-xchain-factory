# @version 0.2.16
"""
@title Curve Child Chain Gauge Factory
@license MIT
@author Curve.fi
@notice Child chain gauge factory enabling permissionless deployment of cross chain gauges
"""


event OwnershipTransferred:
    _owner: address
    _new_owner: address

event ImplementationUpdated:
    _implementation: address
    _new_implementation: address


owner: public(address)
future_owner: public(address)

get_implementation: public(address)
get_size: public(uint256)
get_gauge: public(address[MAX_UINT256])


@external
def __init__():
    self.owner = msg.sender

    log OwnershipTransferred(ZERO_ADDRESS, msg.sender)


@external
def set_implementation(_implementation: address):
    """
    @notice Set the child gauge implementation
    @param _implementation The child gauge implementation contract address
    """
    assert msg.sender == self.owner

    implementation: address = self.get_implementation
    self.get_implementation = _implementation

    log ImplementationUpdated(implementation, _implementation)


@external
def commit_transfer_ownership(_new_owner: address):
    """
    @notice Transfer ownership of to `_new_owner`
    @param _new_owner New owner address
    """
    assert msg.sender == self.owner  # dev: owner only
    self.future_owner = _new_owner


@external
def accept_transfer_ownership():
    """
    @notice Accept ownership
    @dev Only callable by the future owner
    """
    new_owner: address = self.future_owner
    assert msg.sender == new_owner  # dev: new owner only

    owner: address = self.owner
    self.owner = new_owner

    log OwnershipTransferred(owner, new_owner)
