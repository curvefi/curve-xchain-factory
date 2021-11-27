# @version 0.3.0
"""
@title Root Liquidity Gauge Factory
@license MIT
@author Curve Finance
"""


event TransferOwnership:
    _old_owner: address
    _new_owner: address


owner: public(address)
future_owner: public(address)


@external
def __init__():
    self.owner = msg.sender
    log TransferOwnership(ZERO_ADDRESS, msg.sender)


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
