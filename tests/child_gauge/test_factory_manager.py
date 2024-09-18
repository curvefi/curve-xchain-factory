import brownie


def test_set_root(alice, bob, charlie, child_gauge_factory, child_gauge, root_gauge):
    child_gauge_factory.set_manager(bob, {"from": alice})

    child_gauge.set_root_gauge(root_gauge, {"from": alice})  # owner
    child_gauge.set_root_gauge(root_gauge, {"from": alice})  # manager

    with brownie.reverts():
        child_gauge.set_root_gauge(root_gauge, {"from": charlie})
