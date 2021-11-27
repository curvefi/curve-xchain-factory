# @version 0.3.0
"""
@title Root Liquidity Gauge Factory
@license MIT
@author Curve Finance
"""


event UpdateImplementation:
    _old_implementation: address
    _new_implementation: address

event TransferOwnership:
    _old_owner: address
    _new_owner: address


get_implementation: public(address)

owner: public(address)
future_owner: public(address)


@external
def __init__():
    self.owner = msg.sender
    log TransferOwnership(ZERO_ADDRESS, msg.sender)


@external
def set_implementation(_implementation: address):
    """
    @notice Set the implementation
    @param _implementation The address of the implementation to use
    """
    assert msg.sender == self.owner

    log UpdateImplementation(self.get_implementation, _implementation)
    self.get_implementation = _implementation


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
