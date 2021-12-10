import brownie
from brownie import compile_source
from brownie.convert.datatypes import HexString


def test_push_vedata_successful(alice, chain, child_manager, root_manager, mock_bridger):
    tx = root_manager.push_ve_data(chain.id, alice, {"from": alice})
    subcall = tx.subcalls[-1]

    sig = "anyCall(address[],bytes[],address[],uint256[],uint256)"

    assert subcall["function"] == sig
    assert subcall["inputs"] == {
        "callbacks": [],
        "data": [
            HexString(
                child_manager.receive_ve_data.encode_input(alice, 0, 0, 0, tx.timestamp), "bytes"
            )
        ],
        "nonces": [],
        "to": [root_manager.address],
        "toChainID": chain.id,
    }


def test_push_vedata_unsuccessful(alice, root_manager, mock_bridger):
    src = """
interface RootManager:
    def push_ve_data(_chain_id: uint256, _user: address): nonpayable


@external
def push(_manager: address):
    RootManager(_manager).push_ve_data(chain.id, ZERO_ADDRESS)
    """

    mock = compile_source(src, vyper_version="0.3.1").Vyper.deploy({"from": alice})
    with brownie.reverts():
        mock.push(root_manager, {"from": alice})
