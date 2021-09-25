# @version 0.2.16
"""
@title Curve Child Chain Streamer Implementation
@license MIT
@author Curve.fi
@notice Child chain streamer implementation
"""


event OwnershipTransferred:
    _owner: address
    _new_owner: address


owner: public(address)
future_owner: public(address)


@external
def __init__():
    self.owner = msg.sender

    log OwnershipTransferred(ZERO_ADDRESS, msg.sender)


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
