import pytest

WEEK = 86400 * 7


@pytest.fixture(scope="module", autouse=True)
def setup(alice, child_gauge, lp_token):
    lp_token.approve(child_gauge, 10 ** 21, {"from": alice})
    lp_token._mint_for_testing(alice, 10 ** 21, {"from": alice})


def test_inflation_rate_increases(alice, chain, child_gauge, child_crv_token, child_minter):
    chain.mine(timestamp=(chain.time() // WEEK) * WEEK + WEEK + 86400)
    child_gauge.deposit(10 ** 21, {"from": alice})

    week_i = chain.time() // WEEK

    # inflation is default 0 for the week
    assert child_gauge.inflation_rate(week_i) == 0

    # send rewards into the gauge
    child_crv_token._mint_for_testing(child_gauge, 10 ** 24, {"from": alice})
    # interact with the gauge (necessary to update the inflation rate)
    tx = child_gauge.user_checkpoint(alice, {"from": alice})
    expected_inflation_rate = 10 ** 24 // ((week_i + 1) * WEEK - tx.timestamp)
    assert child_gauge.inflation_rate(week_i) == expected_inflation_rate

    # check balance is forwarded to minter
    assert child_crv_token.balanceOf(child_gauge) == 0
    assert child_crv_token.balanceOf(child_minter) == 10 ** 24

    assert child_gauge.integrate_inv_supply(child_gauge.period()) == 0


def test_multiple_emissions_deposits(alice, chain, child_gauge, child_crv_token, child_minter):
    # day into the week
    chain.mine(timestamp=(chain.time() // WEEK) * WEEK + WEEK + 86400)
    child_gauge.deposit(10 ** 21, {"from": alice})

    week_i = chain.time() // WEEK

    # send rewards into the gauge
    child_crv_token._mint_for_testing(child_gauge, 10 ** 24, {"from": alice})
    # interact with the gauge (necessary to update the inflation rate)
    tx = child_gauge.user_checkpoint(alice, {"from": alice})
    expected_inflation_rate = 10 ** 24 // ((week_i + 1) * WEEK - tx.timestamp)
    assert child_gauge.inflation_rate(week_i) == expected_inflation_rate

    # sleep a day
    chain.sleep(86400)

    # send rewards into the gauge new amount
    child_crv_token._mint_for_testing(child_gauge, 10 ** 43, {"from": alice})
    # interact with the gauge (necessary to update the inflation rate)
    tx = child_gauge.user_checkpoint(alice, {"from": alice})
    expected_inflation_rate += 10 ** 43 // ((week_i + 1) * WEEK - tx.timestamp)
    assert child_gauge.inflation_rate(week_i) == expected_inflation_rate

    # completely new period
    chain.sleep(WEEK * 2)

    week_i += 2

    assert child_gauge.inflation_rate(week_i) == 0

    # send rewards into the gauge new amount
    child_crv_token._mint_for_testing(child_gauge, 10 ** 35, {"from": alice})
    # interact with the gauge (necessary to update the inflation rate)
    tx = child_gauge.user_checkpoint(alice, {"from": alice})
    # inflation will start from beginning of the week instead of last period time
    expected_inflation_rate = 10 ** 35 // ((week_i + 1) * WEEK - tx.timestamp)
    assert child_gauge.inflation_rate(week_i) == expected_inflation_rate
