import pytest
from brownie_tokens import MintableForkToken


@pytest.fixture
def crv_token(alice):
    crv = MintableForkToken("0xD533a949740bb3306d119CC777fa900bA034cd52")
    crv._mint_for_testing(alice, 10 ** 18, {"from": alice})
    return crv


def test_arbitrum_bridger(alice, crv_token, ArbitrumBridger):
    gas_limit, gas_price, submission_cost = 1_000_000, 2 * 10 ** 9, 10 ** 13
    bridger = ArbitrumBridger.deploy(gas_limit, gas_price, submission_cost, {"from": alice})

    assert bridger.cost() == gas_limit * gas_price + submission_cost
    assert bridger.check(alice) is True

    crv_token.approve(bridger, 2 ** 256 - 1, {"from": alice})
    tx = bridger.bridge(crv_token, alice, 10 ** 18, {"from": alice, "value": bridger.cost()})

    assert "DepositInitiated" in tx.events
    assert tx.events["DepositInitiated"]["_to"] == alice
    assert tx.events["DepositInitiated"]["_amount"] == 10 ** 18
