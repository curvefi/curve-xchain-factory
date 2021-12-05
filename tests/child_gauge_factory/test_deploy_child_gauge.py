import brownie
from brownie import ETH_ADDRESS
from brownie.convert.datatypes import HexString
from eth_abi import abi


def test_deploy_child_gauge(
    alice,
    chain,
    child_gauge_factory,
    child_gauge_impl,
    lp_token,
    vyper_proxy_init_code,
    create2_address_of,
    web3,
):
    proxy_init_code = vyper_proxy_init_code(child_gauge_impl.address)
    salt = abi.encode_single(
        "(uint256,address,bytes32)", [chain.id, alice.address, (0).to_bytes(32, "big")]
    )
    expected = create2_address_of(child_gauge_factory.address, web3.keccak(salt), proxy_init_code)

    tx = child_gauge_factory.deploy_gauge(lp_token, 0x0, {"from": alice})

    assert tx.return_value == expected
    assert child_gauge_factory.get_gauge(0) == expected
    assert child_gauge_factory.get_gauge_count() == 1
    assert child_gauge_factory.get_gauge_from_lp_token(lp_token) == expected
    assert "DeployedGauge" in tx.events
    assert tx.events["DeployedGauge"].values() == [
        child_gauge_impl,
        lp_token,
        alice,
        HexString(0, "bytes32"),
        expected,
    ]


def test_deploy_child_gauge_repeat_lp_token(alice, bob, child_gauge_factory, lp_token):
    child_gauge_factory.deploy_gauge(lp_token, 0x0, {"from": alice})

    with brownie.reverts():
        child_gauge_factory.deploy_gauge(lp_token, 0x0, {"from": bob})


def test_deploy_child_gauge_repeat_salt(alice, child_gauge_factory, lp_token):
    child_gauge_factory.deploy_gauge(lp_token, 0x0, {"from": alice})

    with brownie.reverts():
        child_gauge_factory.deploy_gauge(ETH_ADDRESS, 0x0, {"from": alice})


def test_request_emissions(alice, child_gauge_factory, lp_token, web3):
    gauge = child_gauge_factory.deploy_gauge(lp_token, 0x0, {"from": alice}).return_value
    child_gauge_factory.set_permitted(gauge, True, {"from": alice})
    internal = web3.keccak(text="transmit_emissions(address)")[:4] + abi.encode_single(
        "address", gauge
    )

    expected_inputs = {
        "callbacks": [],
        "data": [HexString(internal, "bytes")],
        "nonces": [],
        "to": [child_gauge_factory.address],
        "toChainID": 1,
    }

    tx = child_gauge_factory.request_emissions({"from": gauge})
    assert tx.subcalls[0]["inputs"] == expected_inputs
