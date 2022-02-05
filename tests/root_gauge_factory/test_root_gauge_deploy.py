import brownie
from brownie import ETH_ADDRESS, compile_source
from brownie.convert.datatypes import HexString
from eth_abi import abi


def test_deploy_root_gauge(
    alice,
    chain,
    root_gauge_factory,
    root_gauge_impl,
    vyper_proxy_init_code,
    create2_address_of,
    web3,
):
    proxy_init_code = vyper_proxy_init_code(root_gauge_impl.address)
    salt = abi.encode_single(
        "(uint256,address,bytes32)", [chain.id, alice.address, (0).to_bytes(32, "big")]
    )
    expected = create2_address_of(root_gauge_factory.address, web3.keccak(salt), proxy_init_code)

    tx = root_gauge_factory.deploy_gauge(chain.id, 0x0, {"from": alice})

    assert tx.return_value == expected
    assert root_gauge_factory.get_gauge(chain.id, 0) == expected
    assert root_gauge_factory.get_gauge_count(chain.id) == 1
    assert "DeployedGauge" in tx.events
    assert tx.events["DeployedGauge"].values() == [
        root_gauge_impl,
        chain.id,
        alice,
        HexString(0, "bytes32"),
        expected,
    ]


def test_deploy_child_gauge_repeat_salt(alice, chain, root_gauge_factory):
    root_gauge_factory.deploy_gauge(chain.id, 0x0, {"from": alice})

    with brownie.reverts():
        root_gauge_factory.deploy_gauge(chain.id, 0x0, {"from": alice})


def test_transmit_emissions(alice, root_gauge_factory):
    src = """
@external
def transmit_emissions():
    pass
    """
    mock = compile_source(src, vyper_version="0.3.1").Vyper.deploy({"from": alice})
    tx = root_gauge_factory.transmit_emissions(mock, {"from": alice})

    assert tx.subcalls[0]["function"] == "transmit_emissions()"


def test_deploy_gauge(alice, chain, root_gauge_factory, child_gauge_factory, mock_bridger):
    tx = root_gauge_factory.deploy_child_gauge(chain.id, ETH_ADDRESS, 0x0, {"from": alice})

    subcall = tx.subcalls[-1]

    sig = "anyCall(address[],bytes[],address[],uint256[],uint256)"

    assert subcall["function"] == sig
    assert subcall["inputs"] == {
        "callbacks": [],
        "data": [
            HexString(
                child_gauge_factory.deploy_gauge.encode_input(ETH_ADDRESS, 0x0, alice), "bytes"
            )
        ],
        "nonces": [],
        "to": [root_gauge_factory.address],
        "toChainID": chain.id,
    }
