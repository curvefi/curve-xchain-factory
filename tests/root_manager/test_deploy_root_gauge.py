import brownie
from brownie import ETH_ADDRESS, compile_source
from brownie.convert.datatypes import HexString


def test_deploy_gauge(alice, chain, root_manager, child_manager, mock_bridger):
    salt = root_manager.salt()
    tx = root_manager.deploy_gauge(chain.id, ETH_ADDRESS, {"from": alice})

    subcall = tx.subcalls[-1]

    sig = "anyCall(address[],bytes[],address[],uint256[],uint256)"

    assert subcall["function"] == sig
    assert subcall["inputs"] == {
        "callbacks": [root_manager.address],
        "data": [
            HexString(child_manager.deploy_gauge.encode_input(ETH_ADDRESS, salt, alice), "bytes")
        ],
        "nonces": [0],
        "to": [root_manager.address],
        "toChainID": chain.id,
    }


def test_deploy_unsuccessful(alice, root_manager, mock_bridger):
    src = """
interface RootManager:
    def deploy_gauge(_chain_id: uint256, _lp_token: address): nonpayable


@external
def push(_manager: address):
    RootManager(_manager).deploy_gauge(chain.id, ZERO_ADDRESS)
    """

    mock = compile_source(src, vyper_version="0.3.1").Vyper.deploy({"from": alice})
    with brownie.reverts():
        mock.push(root_manager, {"from": alice})
