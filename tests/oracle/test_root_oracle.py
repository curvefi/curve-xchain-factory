import brownie
import pytest
from brownie import ETH_ADDRESS, ZERO_ADDRESS
from brownie.convert.datatypes import HexString


@pytest.fixture(autouse=True)
def setup(alice, root_crv_token, chain, root_gauge_factory, root_voting_escrow):
    balance = root_crv_token.balanceOf(alice)

    root_crv_token.approve(root_voting_escrow, 2 ** 256 - 1, {"from": alice})
    root_voting_escrow.create_lock(balance, chain.time() + 86400 * 365 * 3, {"from": alice})
    root_gauge_factory.set_bridger(chain.id, ETH_ADDRESS, {"from": alice})


def test_push(alice, chain, root_oracle, root_voting_escrow, child_oracle, anycall):
    tx = root_oracle.push(chain.id, {"from": alice})

    subcall = tx.subcalls[-1]

    sig = "anyCall(address,bytes,address,uint256)"

    user_point = root_voting_escrow.user_point_history(
        alice, root_voting_escrow.user_point_epoch(alice)
    )[:-1]
    global_point = root_voting_escrow.point_history(root_voting_escrow.epoch())[:-1]

    assert subcall["function"] == sig
    assert subcall["inputs"] == {
        "_fallback": ZERO_ADDRESS,
        "_data": HexString(
            child_oracle.receive.encode_input(user_point, global_point, alice), "bytes"
        ),
        "_to": root_oracle.address,
        "_toChainID": chain.id,
    }


def test_receive(alice, anycall, root_voting_escrow, child_oracle):
    user_point = root_voting_escrow.user_point_history(
        alice, root_voting_escrow.user_point_epoch(alice)
    )[:-1]
    global_point = root_voting_escrow.point_history(root_voting_escrow.epoch())[:-1]

    child_oracle.receive(user_point, global_point, alice, {"from": anycall})

    assert child_oracle.balanceOf(alice) == root_voting_escrow.balanceOf(alice)
    assert child_oracle.totalSupply() == child_oracle.totalSupply()


def test_receive_guarded(alice, root_voting_escrow, child_oracle):
    user_point = root_voting_escrow.user_point_history(
        alice, root_voting_escrow.user_point_epoch(alice)
    )[:-1]
    global_point = root_voting_escrow.point_history(root_voting_escrow.epoch())[:-1]

    with brownie.reverts():
        child_oracle.receive(user_point, global_point, alice, {"from": alice})
