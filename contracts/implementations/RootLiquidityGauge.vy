# @version 0.3.0
"""
@title Root Liquidity Gauge Implementation
@license MIT
@author Curve Finance
"""


interface GaugeController:
    def checkpoint_gauge(addr: address): nonpayable
    def gauge_relative_weight(addr: address, time: uint256) -> uint256: view

interface Factory:
    def inflation_params_write() -> InflationParams: nonpayable


struct InflationParams:
    rate: uint256
    finish_time: uint256


GAUGE_CONTROLLER: constant(address) = 0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB
WEEK: constant(uint256) = 86400 * 7


chain_id: public(uint256)
factory: public(address)
inflation_params: public(InflationParams)

last_period: public(uint256)
total_emissions: public(uint256)


@external
def __init__():
    self.factory = 0x000000000000000000000000000000000000dEaD


@internal
def _updated_inflation_params() -> InflationParams:
    inflation_params: InflationParams = self.inflation_params
    if block.timestamp >= inflation_params.finish_time:
        inflation_params = Factory(self.factory).inflation_params_write()
        self.inflation_params = inflation_params
        return inflation_params
    return inflation_params


@external
def user_checkpoint(_user: address) -> bool:
    """
    @notice Checkpoint the gauge updating total emissions
    @param _user Vestigal parameter with no impact on the function
    """
    # the last period we calculated emissions up to (but not including)
    last_period: uint256 = self.last_period
    # our current period (which we will calculate emissions up to)
    current_period: uint256 = block.timestamp / WEEK

    # only checkpoint if the current period is greater than the last period
    # last period is always less than current period and we only calculate
    # emissions up to current period (not including it)
    if last_period != current_period:
        # checkpoint the gauge filling in any missing weight data
        GaugeController(GAUGE_CONTROLLER).checkpoint_gauge(self)

        params: InflationParams = self.inflation_params
        emissions: uint256 = 0

        # only calculate emissions for at most 256 periods since the last checkpoint
        for i in range(last_period, last_period + 256):
            if i == current_period:
                # don't calculate emissions for the current period
                break
            period_time: uint256 = i * WEEK
            weight: uint256 = GaugeController(GAUGE_CONTROLLER).gauge_relative_weight(self, period_time)

            if period_time <= params.finish_time and params.finish_time < period_time + WEEK:
                # if we cross multiple epochs, the rate of the first epoch is
                # applied until it ends, and then the rate of the last epoch
                # is applied for the rest of the periods. This means the gauge
                # will receive less emissions, however it also means the gauge
                # hasn't been called in over a year.
                emissions += weight * params.rate * (params.finish_time - period_time) / 10 ** 18
                params = self._updated_inflation_params()
                emissions += weight * params.rate * (period_time + WEEK - params.finish_time) / 10 ** 18
            else:
                emissions += weight * params.rate * WEEK / 10 ** 18

        self.last_period = current_period
        self.total_emissions += emissions

    return True


@external
def initialize(_chain_id: uint256, _inflation_params: InflationParams):
    assert self.factory == ZERO_ADDRESS  # dev: already initialized

    self.chain_id = _chain_id
    self.factory = msg.sender
    self.inflation_params = _inflation_params
    self.last_period = block.timestamp / WEEK
