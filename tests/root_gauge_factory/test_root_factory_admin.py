import brownie
from brownie import ETH_ADDRESS


def test_set_implementation(alice, root_gauge_impl, root_gauge_factory):
    tx = root_gauge_factory.set_implementation(ETH_ADDRESS, {"from": alice})

    assert root_gauge_factory.get_implementation() == ETH_ADDRESS
    assert "UpdateImplementation" in tx.events
    assert tx.events["UpdateImplementation"].values() == [root_gauge_impl.address, ETH_ADDRESS]


def test_set_implementation_guarded(bob, root_gauge_factory):
    with brownie.reverts():
        root_gauge_factory.set_implementation(ETH_ADDRESS, {"from": bob})


def test_set_child(alice, chain, root_gauge_factory):
    tx = root_gauge_factory.set_child(chain.id, ETH_ADDRESS, ETH_ADDRESS, ETH_ADDRESS,
                                      {"from": alice})

    assert root_gauge_factory.get_bridger(chain.id) == ETH_ADDRESS
    assert root_gauge_factory.get_child_factory(chain.id) == ETH_ADDRESS
    assert root_gauge_factory.get_child_implementation(chain.id) == ETH_ADDRESS
    assert "ChildUpdated" in tx.events
    assert tx.events["ChildUpdated"].values() == [chain.id, ETH_ADDRESS, ETH_ADDRESS, ETH_ADDRESS]


def test_set_child_updated(bob, chain, root_gauge_factory):
    with brownie.reverts():
        root_gauge_factory.set_child(chain.id, ETH_ADDRESS, ETH_ADDRESS, ETH_ADDRESS, {"from": bob})
