import brownie
from brownie import ETH_ADDRESS, ZERO_ADDRESS


def test_set_implementation(alice, root_gauge_factory):
    tx = root_gauge_factory.set_implementation(ETH_ADDRESS, {"from": alice})

    assert root_gauge_factory.get_implementation() == ETH_ADDRESS
    assert "UpdateImplementation" in tx.events
    assert tx.events["UpdateImplementation"].values() == [ZERO_ADDRESS, ETH_ADDRESS]


def test_set_implementation_guarded(bob, root_gauge_factory):
    with brownie.reverts():
        root_gauge_factory.set_implementation(ETH_ADDRESS, {"from": bob})


def test_set_bridger(alice, chain, root_gauge_factory):
    tx = root_gauge_factory.set_bridger(chain.id, ETH_ADDRESS, {"from": alice})

    assert root_gauge_factory.get_bridger(chain.id) == ETH_ADDRESS
    assert "BridgerUpdated" in tx.events
    assert tx.events["BridgerUpdated"].values() == [chain.id, ZERO_ADDRESS, ETH_ADDRESS]


def test_set_bridger_updated(bob, chain, root_gauge_factory):
    with brownie.reverts():
        root_gauge_factory.set_bridger(chain.id, ETH_ADDRESS, {"from": bob})
