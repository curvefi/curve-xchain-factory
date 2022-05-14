import math

import pytest

WEEK = 86400 * 7


@pytest.fixture(scope="module", autouse=True)
def setup(alice, child_gauge, lp_token):
    lp_token.approve(child_gauge, 10**21, {"from": alice})
    lp_token._mint_for_testing(alice, 10**21, {"from": alice})


def test_inflation_rate_increases(alice, chain, child_gauge, child_crv_token, child_gauge_factory):
    # go to start of the week
    chain.mine(timestamp=(chain.time() // WEEK) * WEEK + WEEK + 86400)
    child_gauge.deposit(10**21, {"from": alice})

    # send rewards into the gauge
    child_crv_token._mint_for_testing(child_gauge, 10**24, {"from": alice})

    # check balance is forwarded to minter
    child_gauge.user_checkpoint(alice, {"from": alice})
    assert child_crv_token.balanceOf(child_gauge) == 0
    assert child_crv_token.balanceOf(child_gauge_factory) == 10**24

    chain.sleep(WEEK)

    child_gauge_factory.mint(child_gauge, {"from": alice})
    assert math.isclose(child_crv_token.balanceOf(alice), 10**24)


def test_request_only_once_a_week(alice, child_gauge, child_gauge_factory):
    child_gauge_factory.set_mirrored(child_gauge, True, {"from": alice})
    sig = "anyCall(address,bytes,address,uint256)"
    tx = child_gauge_factory.mint(child_gauge, {"from": alice})
    assert sig in {s.get("function") for s in tx.subcalls}

    tx = child_gauge_factory.mint(child_gauge, {"from": alice})
    assert sig not in {s.get("function") for s in tx.subcalls}


def test_request_only_if_has_counterpart(alice, child_gauge, child_gauge_factory):
    sig = "anyCall(address,bytes,address,uint256)"

    tx = child_gauge_factory.mint(child_gauge, {"from": alice})
    assert sig not in {s.get("function") for s in tx.subcalls}

    child_gauge_factory.set_mirrored(child_gauge, True, {"from": alice})
    tx = child_gauge_factory.mint(child_gauge, {"from": alice})
    assert sig in {s.get("function") for s in tx.subcalls}
