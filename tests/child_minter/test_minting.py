import math

import pytest
from brownie import compile_source

WEEK = 86400 * 7


@pytest.fixture(scope="module", autouse=True)
def setup(alice, child_gauge, lp_token):
    lp_token.approve(child_gauge, 10 ** 21, {"from": alice})
    lp_token._mint_for_testing(alice, 10 ** 21, {"from": alice})


def test_inflation_rate_increases(alice, chain, child_gauge, child_crv_token, child_minter):
    # go to start of the week
    chain.mine(timestamp=(chain.time() // WEEK) * WEEK + WEEK + 86400)
    child_gauge.deposit(10 ** 21, {"from": alice})

    # send rewards into the gauge
    child_crv_token._mint_for_testing(child_gauge, 10 ** 24, {"from": alice})

    # check balance is forwarded to minter
    child_gauge.user_checkpoint(alice, {"from": alice})
    assert child_crv_token.balanceOf(child_gauge) == 0
    assert child_crv_token.balanceOf(child_minter) == 10 ** 24

    chain.sleep(WEEK)

    child_minter.mint(child_gauge, {"from": alice})
    assert math.isclose(child_crv_token.balanceOf(alice), 10 ** 24)


def test_request_only_if_called_by_EOA(alice, child_gauge, child_minter):
    child_minter.set_has_counterpart(child_gauge, True, {"from": alice})
    src = """
interface Minter:
    def mint(_gauge: address): nonpayable

@external
def mint(_minter: address, _gauge: address):
    Minter(_minter).mint(_gauge)
    """

    mock = compile_source(src, vyper_version="0.3.1").Vyper.deploy({"from": alice})
    sig = "anyCall(address[],bytes[],address[],uint256[],uint256)"

    tx = mock.mint(child_minter, child_gauge, {"from": alice})
    assert sig not in {s.get("function") for s in tx.subcalls}

    tx = child_minter.mint(child_gauge, {"from": alice})
    assert sig in {s.get("function") for s in tx.subcalls}
