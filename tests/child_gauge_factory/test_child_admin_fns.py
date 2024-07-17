import brownie
from brownie import ETH_ADDRESS, ZERO_ADDRESS


def test_set_voting_escrow(alice, child_gauge_factory):
    tx = child_gauge_factory.set_voting_escrow(ETH_ADDRESS, {"from": alice})

    assert child_gauge_factory.voting_escrow() == ETH_ADDRESS
    assert "UpdateVotingEscrow" in tx.events
    assert tx.events["UpdateVotingEscrow"].values() == [ZERO_ADDRESS, ETH_ADDRESS]


def test_set_voting_escrow_guarded(bob, child_gauge_factory):
    with brownie.reverts():
        child_gauge_factory.set_voting_escrow(ETH_ADDRESS, {"from": bob})


def test_set_implementation(alice, child_gauge_impl, child_gauge_factory):
    tx = child_gauge_factory.set_implementation(ETH_ADDRESS, {"from": alice})

    assert child_gauge_factory.get_implementation() == ETH_ADDRESS
    assert "UpdateImplementation" in tx.events
    assert tx.events["UpdateImplementation"].values() == [child_gauge_impl.address, ETH_ADDRESS]


def test_set_implementation_guarded(bob, child_gauge_factory):
    with brownie.reverts():
        child_gauge_factory.set_implementation(ETH_ADDRESS, {"from": bob})
