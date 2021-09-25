# @version 0.2.16
"""
@title Curve Child Chain Streamer Implementation
@license MIT
@author Curve.fi
@notice Child chain streamer implementation
"""


interface StreamerFactory:
    def owner() -> address: view


event OwnershipTransferred:
    _owner: address
    _new_owner: address

event ReceiverUpdated:
    _old_receiver: address
    _new_receiver: address


owner: public(address)
future_owner: public(address)

is_initialized: public(bool)

# values set when initialized
streamer_factory: public(address)
deployer: public(address)
receiver: public(address)


@external
def __init__():
    self.owner = msg.sender
    # prevent the implementation from being initialized
    self.is_initialized = True

    log OwnershipTransferred(ZERO_ADDRESS, msg.sender)


@external
def initialize(_deployer: address, _receiver: address):
    assert not self.is_initialized  # dev: already initialized

    self.is_initialized = True

    self.streamer_factory = msg.sender
    self.deployer = _deployer
    self.receiver = _receiver

    log ReceiverUpdated(ZERO_ADDRESS, _receiver)


@external
def set_receiver(_receiver: address):
    assert msg.sender == StreamerFactory(self.streamer_factory).owner()

    old_receiver: address = self.receiver
    self.receiver = _receiver

    log ReceiverUpdated(old_receiver, _receiver)


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
