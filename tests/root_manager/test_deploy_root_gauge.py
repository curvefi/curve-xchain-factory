from brownie import ETH_ADDRESS
from brownie.convert.datatypes import HexString


def test_deploy_gauge(alice, chain, root_gauge_factory, child_gauge_factory, mock_bridger):
    tx = root_gauge_factory.deploy_child_gauge(chain.id, ETH_ADDRESS, 0x0, {"from": alice})

    subcall = tx.subcalls[-1]

    sig = "anyCall(address[],bytes[],address[],uint256[],uint256)"

    assert subcall["function"] == sig
    assert subcall["inputs"] == {
        "callbacks": [root_gauge_factory.address],
        "data": [
            HexString(
                child_gauge_factory.deploy_gauge.encode_input(ETH_ADDRESS, 0x0, alice), "bytes"
            )
        ],
        "nonces": [0],
        "to": [root_gauge_factory.address],
        "toChainID": chain.id,
    }
