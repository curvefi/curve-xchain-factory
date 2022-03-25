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
    expected = {
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
    assert {k: v for k, v in tx.subcalls[0].items() if k in expected} == expected


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


@pytest.mark.xfail
def test_optimism_bridger(alice, crv_token, OptimismBridger):
    # oddly in mainnet-fork this test fails due to the bridger contract's CRV balance
    # not updating properly during the bridge tx, however works in live mainnet env
    # https://etherscan.io/tx/0xd1a74f4df8c49e7a53c624c1cbec2af9cecf92f0c960488ce173e2cf6205882b/advanced
    optimism_bridge = "0x99C9fc46f92E8a1c0deC1b1747d010903E884bE1"
    l2_crv = "0x0994206dfE8De6Ec6920FF4D779B0d950605Fb53"
    bridger = OptimismBridger.deploy({"from": alice})

    assert bridger.cost() == 0
    assert bridger.check(alice) is True

    crv_token.approve(bridger, 2 ** 256 - 1, {"from": alice})

    balance_before = crv_token.balanceOf(optimism_bridge)
    tx = bridger.bridge(crv_token, alice, 10 ** 18, {"from": alice, "value": bridger.cost()})

    assert crv_token.balanceOf(optimism_bridge) == balance_before + 10 ** 18
    assert "ERC20DepositInitiated" in tx.events
    assert tx.events["TokensBridgingInitiated"].values() == [
        crv_token,
        l2_crv,
        bridger,
        alice,
        10 ** 18,
        b"",
    ]


def test_polygon_bridger(alice, crv_token, PolygonBridger):
    poly_bridge_rec = "0x40ec5B33f54e0E8A33A975908C5BA1c14e5BbbDf"
    bridger = PolygonBridger.deploy({"from": alice})

    assert bridger.cost() == 0
    assert bridger.check(alice) is True

    crv_token.approve(bridger, 2 ** 256 - 1, {"from": alice})

    balance_before = crv_token.balanceOf(poly_bridge_rec)
    tx = bridger.bridge(crv_token, alice, 10 ** 18, {"from": alice, "value": bridger.cost()})

    assert crv_token.balanceOf(poly_bridge_rec) == balance_before + 10 ** 18
    assert "LockedERC20" in tx.events
    assert tx.events["LockedERC20"]["rootToken"] == crv_token
    assert tx.events["LockedERC20"]["amount"] == 10 ** 18


def test_harmony_bridger(alice, crv_token, HarmonyBridger):
    harmony_bridge = "0x2dCCDB493827E15a5dC8f8b72147E6c4A5620857"
    bridger = HarmonyBridger.deploy({"from": alice})

    assert bridger.cost() == 0
    assert bridger.check(alice) is True

    crv_token.approve(bridger, 2 ** 256 - 1, {"from": alice})

    balance_before = crv_token.balanceOf(harmony_bridge)
    tx = bridger.bridge(crv_token, alice, 10 ** 18, {"from": alice})

    assert crv_token.balanceOf(harmony_bridge) == balance_before + 10 ** 18
    assert "Locked" in tx.events
    assert tx.events["Locked"].values() == [crv_token, bridger, 10 ** 18, alice]
