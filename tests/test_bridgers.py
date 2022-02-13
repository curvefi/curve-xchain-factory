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


def test_multichain_bridger(alice, crv_token, MultichainBridger):
    anyswap_bridge = "0xC564EE9f21Ed8A2d8E7e76c085740d5e4c5FaFbE"
    bridger = MultichainBridger.deploy(
        "0x37414a8662bc1d25be3ee51fb27c2686e2490a89", anyswap_bridge, {"from": alice}
    )

    assert bridger.cost() == 0
    assert bridger.check(alice) is True

    crv_token.approve(bridger, 2 ** 256 - 1, {"from": alice})
    balance_before = crv_token.balanceOf(anyswap_bridge)
    tx = bridger.bridge(crv_token, alice, 10 ** 18, {"from": alice, "value": bridger.cost()})

    assert crv_token.balanceOf(anyswap_bridge) == balance_before + 10 ** 18
    assert len(tx.subcalls) == 1
    assert tx.subcalls[0] == {
        "from": bridger,
        "function": "transferFrom(address,address,uint256)",
        "inputs": {
            "_from": alice,
            "_to": anyswap_bridge,
            "_value": 10 ** 18,
        },
        "op": "CALL",
        "to": crv_token,
        "value": 0,
    }


def test_omni_bridger(alice, crv_token, OmniBridger):
    omni_bridge = "0x88ad09518695c6c3712AC10a214bE5109a655671"
    bridger = OmniBridger.deploy({"from": alice})

    assert bridger.cost() == 0
    assert bridger.check(alice) is True

    crv_token.approve(bridger, 2 ** 256 - 1, {"from": alice})

    balance_before = crv_token.balanceOf(omni_bridge)
    tx = bridger.bridge(crv_token, alice, 10 ** 18, {"from": alice, "value": bridger.cost()})

    assert crv_token.balanceOf(omni_bridge) == balance_before + 10 ** 18
    assert "TokensBridgingInitiated" in tx.events
    assert tx.events["TokensBridgingInitiated"]["token"] == crv_token
