"""
Thanks to the anycall integration the gauge system is 99% automatic when it comes to CRV emissions.
However, for new gauges, they require a kickstart for the first time emissions are to be bridged.
This is due to the fact that future emissions will automatically be bridged as users mint on
the child chain. But when a gauge first begins ... no users will call mint, since there
is nothing to mint.
"""

from inspect import unwrap
from itertools import compress

import brownie
from brownie import Contract, RootGauge, RootGaugeFactory, accounts

NETWORK_IDS = [
    10,  # optimism
    100,  # xdai
    137,  # polygon
    250,  # ftm
    42161,  # arbitrum
    43114,  # avax
    1666600000,  # harmony
]

dev = accounts.load("dev")


def main():
    factory = RootGaugeFactory.at("0xabC000d88f23Bb45525E447528DBF656A9D55bf5")
    gauge_controller = Contract("0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB")  # gauge controller

    with brownie.multicall:
        # fetch all the gauges for each network in NETWORK_IDS
        gauges = [
            factory.get_gauge(chain_id, i)
            for chain_id in NETWORK_IDS
            for i in range(factory.get_gauge_count(chain_id))
        ]
        # fetch each gauges gauge_type, gauges not voted in have no gauge_type
        gauge_types = [gauge_controller.gauge_types(gauge) for gauge in gauges]

        # filter gauges that have been voted in by the Curve DAO
        valid_gauges = list(compress(gauges, map(lambda t: unwrap(t) is not None, gauge_types)))

        # we want all the gauges with 0 as total_emissions because these are new
        gauge_emissions = [
            RootGauge.at(gauge_addr).total_emissions() for gauge_addr in valid_gauges
        ]
        # filter gauges that haven't emitted any CRV
        transmission_set = list(compress(valid_gauges, map(lambda e: e == 0, gauge_emissions)))

    gauges_to_emit = []
    for gauge_addr in transmission_set:
        try:
            factory.transmit_emissions.call(gauge_addr)
            factory.transmit_emissions(gauge_addr, {"from": dev, "priority_fee": "2 gwei"})
        except Exception:
            pass
    if len(gauges_to_emit) != 0:
        print(gauges_to_emit)
    else:
        print("No gauges required a kickstart")
