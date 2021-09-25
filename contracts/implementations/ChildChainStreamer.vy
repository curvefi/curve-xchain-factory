# @version 0.2.16
"""
@title Curve Child Chain Streamer Implementation
@license MIT
@author Curve.fi
@notice Child chain streamer implementation
"""


interface StreamerFactory:
    def owner() -> address: view
    def reward_token() -> address: view


event ReceiverUpdated:
    _old_receiver: address
    _new_receiver: address


# values set when initialized
streamer_factory: public(address)
deployer: public(address)
receiver: public(address)


@external
def initialize(_deployer: address, _receiver: address):
    assert self.receiver == ZERO_ADDRESS

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
