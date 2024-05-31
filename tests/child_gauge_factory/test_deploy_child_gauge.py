import brownie
from brownie import ETH_ADDRESS, ZERO_ADDRESS
from brownie.convert.datatypes import HexString
from eth_abi import encode


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
    salt = encode(
        ["(uint256,address,bytes32)"], [(chain.id, alice.address, (0).to_bytes(32, "big"))]
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


def test_deploy_child_gauge_anycall(
    anycall,
    chain,
    child_gauge_factory,
    root_gauge_factory,
    lp_token,
):
    tx = child_gauge_factory.deploy_gauge(lp_token, 0x0, {"from": anycall})

    assert "AnyCall" in tx.events
    subcall = tx.subcalls[1]

    sig = "anyCall(address,bytes,address,uint256)"

    assert subcall["function"] == sig
    assert subcall["inputs"] == {
        "_fallback": ZERO_ADDRESS,
        "_data": HexString(root_gauge_factory.deploy_gauge.encode_input(chain.id, 0x0), "bytes"),
        "_to": child_gauge_factory.address,
        "_toChainID": 1,
    }


def test_deploy_child_gauge_repeat_lp_token(alice, bob, child_gauge_factory, lp_token):
    child_gauge_factory.deploy_gauge(lp_token, 0x0, {"from": alice})

    with brownie.reverts():
        child_gauge_factory.deploy_gauge(lp_token, 0x0, {"from": bob})


def test_deploy_child_gauge_repeat_salt(alice, child_gauge_factory, lp_token):
    child_gauge_factory.deploy_gauge(lp_token, 0x0, {"from": alice})

    with brownie.reverts():
        child_gauge_factory.deploy_gauge(ETH_ADDRESS, 0x0, {"from": alice})
