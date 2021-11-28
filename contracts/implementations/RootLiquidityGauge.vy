# @version 0.3.0
"""
@title Root Liquidity Gauge Implementation
@license MIT
@author Curve Finance
"""


chain_id: public(uint256)
factory: public(address)


@external
def __init__():
    self.factory = 0x000000000000000000000000000000000000dEaD


@external
def initialize(_chain_id: uint256):
    assert self.factory == ZERO_ADDRESS  # dev: already initialized

    self.chain_id = _chain_id
    self.factory = msg.sender
