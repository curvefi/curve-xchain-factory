# @version 0.2.16
"""
@title Curve Child Chain Streamer Implementation
@license MIT
@author Curve.fi
@notice Child chain streamer implementation
"""


interface Factory:
    def owner() -> address: view
    def reward_token() -> address: view


event ReceiverUpdated:
    _old_receiver: address
    _new_receiver: address


WEEK: constant(uint256) = 604800


# values set when initialized
factory: public(Factory)
deployer: public(address)
receiver: public(address)

# rate of rewards distributed per second over distribution period
rate: public(uint256)
# [period_finish uint128][last_update uint128]
time_data: uint256
# [received uint128][paid uint128]
reward_data: uint256


@internal
def _update():
    # load time data from storage
    time_data: uint256 = self.time_data
    last_update: uint256 = time_data % 2 ** 128
    period_finish: uint256 = shift(time_data, -128)

    # check the last time rewards were to be distributed
    last_time: uint256 = min(block.timestamp, period_finish)
    # if we have new rewards to distribute
    if last_time > last_update:
        # get the amount to distribute in this call
        amount: uint256 = (last_time - last_update) * self.rate
        if amount > 0:
            # update reward data with the amount paid
            self.reward_data += amount
            # safeTransfer out the rewards
            response: Bytes[32] = raw_call(
                self.factory.reward_token(),
                _abi_encode(
                    self.receiver, amount, method_id=method_id("transfer(address,uint256)")
                ),
                max_outsize=32,
            )
            if len(response) != 0:
                assert convert(response, bool)

    # change our last update time
    self.time_data = shift(period_finish, 128) + block.timestamp


@external
def get_reward():
    """
    @notice Claim pending rewards for `reward_receiver`
    """
    self._update()


@external
def initialize(_deployer: address, _receiver: address):
    assert self.receiver == ZERO_ADDRESS

    self.factory = Factory(msg.sender)
    self.deployer = _deployer
    self.receiver = _receiver

    log ReceiverUpdated(ZERO_ADDRESS, _receiver)


@external
def set_receiver(_receiver: address):
    assert msg.sender == self.factory.owner()

    old_receiver: address = self.receiver
    self.receiver = _receiver

    log ReceiverUpdated(old_receiver, _receiver)


@view
@external
def period_finish() -> uint256:
    """
    @notice Query timestamp when reward distribution ends
    """
    return shift(self.time_data, -128)


@view
@external
def last_update() -> uint256:
    """
    @notice Query the timestamp of the last reward distribution update
    """
    return self.time_data % 2 ** 128


@view
@external
def reward_received() -> uint256:
    """
    @notice Query the total amount of `reward_token` received
    """
    return shift(self.reward_data, -128)


@view
@external
def reward_paid() -> uint256:
    """
    @notice Query the total amount of `reward_token` paid out
    """
    return self.reward_data % 2 ** 128
