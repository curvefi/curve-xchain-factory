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


def test_set_permitted(alice, child_gauge_factory):
    tx = child_gauge_factory.set_permitted(ETH_ADDRESS, True)

    assert child_gauge_factory.permitted(ETH_ADDRESS) is True
    assert "UpdatePermission" in tx.events
    assert tx.events["UpdatePermission"].values() == [ETH_ADDRESS, True]


def test_set_permitted_guarded(bob, child_gauge_factory):
    with brownie.reverts():
        child_gauge_factory.set_permitted(ETH_ADDRESS, True, {"from": bob})


def test_set_manager(alice, child_gauge_factory):
    tx = child_gauge_factory.set_manager(ETH_ADDRESS, {"from": alice})

    assert child_gauge_factory.manager() == ETH_ADDRESS
    assert "ManagerUpdated" in tx.events
    assert tx.events["ManagerUpdated"].values() == [alice, ETH_ADDRESS]


def test_set_manager_guarded(bob, child_gauge_factory):
    with brownie.reverts():
        child_gauge_factory.set_manager(ETH_ADDRESS, {"from": bob})


def test_set_voting_escrow(alice, child_gauge_factory):
    tx = child_gauge_factory.set_voting_escrow(ETH_ADDRESS, {"from": alice})

    assert child_gauge_factory.voting_escrow() == ETH_ADDRESS
    assert "UpdateVotingEscrow" in tx.events
    assert tx.events["UpdateVotingEscrow"].values() == [ZERO_ADDRESS, ETH_ADDRESS]


def test_set_voting_escrow_guarded(bob, child_gauge_factory):
    with brownie.reverts():
        child_gauge_factory.set_voting_escrow(ETH_ADDRESS, {"from": bob})


def test_set_implementation(alice, child_gauge_factory):
    tx = child_gauge_factory.set_implementation(ETH_ADDRESS, {"from": alice})

    assert child_gauge_factory.get_implementation() == ETH_ADDRESS
    assert "UpdateImplementation" in tx.events
    assert tx.events["UpdateImplementation"].values() == [ZERO_ADDRESS, ETH_ADDRESS]


def test_set_implementation_guarded(bob, child_gauge_factory):
    with brownie.reverts():
        child_gauge_factory.set_implementation(ETH_ADDRESS, {"from": bob})
