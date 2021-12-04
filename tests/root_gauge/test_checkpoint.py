import math

import pytest
from brownie import chain

WEEK = 7 * 86400
YEAR = 365 * 86400


@pytest.mark.skip_coverage
def test_emissions_against_expected(alice, root_gauge_controller, root_gauge, root_crv_token):
    root_gauge_controller.add_type("Test", 10 ** 18, {"from": alice})
    root_gauge_controller.add_gauge(root_gauge, 0, 10 ** 18, {"from": alice})

    chain.mine(timedelta=WEEK)

    rate = root_crv_token.rate()
    total_emissions = 0
    assert rate > 0

    # we now have a one week delay in the emission of rewards, so new emissions from
    # the root gauge should equal the emissions of 1 week prior not 1 week ahead
    # 110 weeks ensures we see 2 reductions in the rate
    for i in range(1, 110):

        this_week = chain.time() // WEEK * WEEK
        last_week = this_week - WEEK
        future_epoch_time = root_gauge.inflation_params()["finish_time"]
        gauge_weight = root_gauge_controller.gauge_relative_weight(root_gauge, last_week)

        # calculate the expected emissions, and checkpoint to update actual emissions
        if last_week <= future_epoch_time < this_week:
            # the core of the maff
            last_week_expected = gauge_weight * rate * (future_epoch_time - last_week) / 10 ** 18
            rate = rate * 10 ** 18 // 1189207115002721024
            last_week_expected += gauge_weight * rate * (this_week - future_epoch_time) / 10 ** 18
        else:
            last_week_expected = gauge_weight * rate * WEEK // 10 ** 18

        root_gauge.user_checkpoint(alice, {"from": alice})

        # actual emissions should equal expected emissions
        new_emissions = root_gauge.total_emissions() - total_emissions
        assert math.isclose(new_emissions, last_week_expected)

        total_emissions += new_emissions

        chain.mine(timedelta=WEEK)

        # crossing over epochs our the rate should be the same as prior to the
        # epoch transition
        if this_week < future_epoch_time < this_week + WEEK:
            root_crv_token.update_mining_parameters({"from": alice})
            assert rate > root_crv_token.rate()
        else:
            assert rate == root_crv_token.rate()
