import brownie
from brownie import ETH_ADDRESS, ZERO_ADDRESS


def test_set_anycall(alice, child_gauge_factory):
    tx = child_gauge_factory.set_anycall(ETH_ADDRESS, {"from": alice})

    assert child_gauge_factory.anycall() == ETH_ADDRESS
    assert "UpdateAnyCall" in tx.events
    assert tx.events["UpdateAnyCall"].values() == [ZERO_ADDRESS, ETH_ADDRESS]


def test_set_anycall_guarded(bob, child_gauge_factory):
    with brownie.reverts():
        child_gauge_factory.set_anycall(ETH_ADDRESS, {"from": bob})
