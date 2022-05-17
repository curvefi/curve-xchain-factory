import brownie
from brownie import ETH_ADDRESS


def test_set_manager(root_gauge_factory_proxy, alice, bob, charlie, chain):

    default_ownership_admin = root_gauge_factory_proxy.ownership_admin()
    default_emergency_admin = root_gauge_factory_proxy.emergency_admin()
    assert root_gauge_factory_proxy.manager() == alice  # contract deployer is manager

    # unauthorised users cannot change the manager:
    with brownie.reverts():
        root_gauge_factory_proxy.set_manager(charlie, {"from": bob})

    # emergency admin and ownership admin can become manager:
    for acct in [default_emergency_admin, default_ownership_admin]:
        root_gauge_factory_proxy.set_manager(acct, {"from": acct})
        assert root_gauge_factory_proxy.manager() == acct
        chain.undo()

    # authorised users can change the manager to anyone:
    for acct in [default_emergency_admin, default_ownership_admin, alice]:
        root_gauge_factory_proxy.set_manager(bob, {"from": acct})
        assert root_gauge_factory_proxy.manager() == bob
        chain.undo()


def test_transfer_proxy_admins(root_gauge_factory_proxy, alice, bob, charlie):

    default_ownership_admin = root_gauge_factory_proxy.ownership_admin()
    default_emergency_admin = root_gauge_factory_proxy.emergency_admin()

    # ---
    # commit future proxy owners

    # manager cannot commit new admins
    with brownie.reverts():
        root_gauge_factory_proxy.commit_set_admins(bob, charlie, {"from": alice})

    # unauthorised accounts cannot commit new admins
    with brownie.reverts():
        root_gauge_factory_proxy.commit_set_admins(bob, bob, {"from": charlie})

    # emergency admin cannot commit new admins
    with brownie.reverts():
        root_gauge_factory_proxy.commit_set_admins(bob, charlie, {"from": default_emergency_admin})

    # commit future owners
    root_gauge_factory_proxy.commit_set_admins(bob, charlie, {"from": default_ownership_admin})
    assert root_gauge_factory_proxy.ownership_admin() == default_ownership_admin
    assert root_gauge_factory_proxy.emergency_admin() == default_emergency_admin
    assert root_gauge_factory_proxy.future_ownership_admin() == bob
    assert root_gauge_factory_proxy.future_emergency_admin() == charlie

    # ---
    # accept new proxy owners

    # unauthorised accts cannot accept future ownership and emergency admins on behalf:
    for acct in [default_ownership_admin, default_emergency_admin, alice, charlie]:
        with brownie.reverts():
            root_gauge_factory_proxy.accept_set_admins({"from": acct})

    root_gauge_factory_proxy.accept_set_admins({"from": bob})
    assert root_gauge_factory_proxy.ownership_admin() == bob
    assert root_gauge_factory_proxy.emergency_admin() == charlie


def test_transfer_ownership(
    alice, bob, charlie, chain, root_gauge_factory, root_gauge_factory_proxy
):

    default_ownership_admin = root_gauge_factory_proxy.ownership_admin()
    default_emergency_admin = root_gauge_factory_proxy.emergency_admin()

    # ---
    # commit transfer ownership: set gauge proxy as future factory owner

    assert root_gauge_factory.owner() == alice  # alice is the owner
    # since proxy contract is not an owner yet, this will revert:
    for acct in [
        default_ownership_admin,
        default_emergency_admin,
        bob,
        charlie,
        root_gauge_factory_proxy,
    ]:
        with brownie.reverts():
            root_gauge_factory_proxy.commit_transfer_ownership(
                root_gauge_factory, root_gauge_factory_proxy, {"from": acct}
            )

    # set proxy as future owner: only factory owner can do this
    root_gauge_factory.commit_transfer_ownership(root_gauge_factory_proxy, {"from": alice})
    assert root_gauge_factory.future_owner() == root_gauge_factory_proxy
    assert root_gauge_factory.owner() == alice  # alice is still the owner

    # ---
    # accept transfer ownership: only proxy (root_gauge_factory.future_owner) can accept
    # this is callable by anyone through the proxy

    # unauthorised accounts cannot complete ownership transfer through the factory
    for acct in [default_ownership_admin, default_emergency_admin, alice, bob, charlie]:
        with brownie.reverts():
            root_gauge_factory.accept_transfer_ownership({"from": acct})

    # completing transfer can be only be done through the root gauge factory proxy now
    for acct in [alice, bob, charlie]:
        root_gauge_factory_proxy.accept_transfer_ownership(root_gauge_factory, {"from": acct})
        assert root_gauge_factory.owner() == root_gauge_factory_proxy
        chain.undo()


def test_set_killed(
    root_gauge,
    root_gauge_factory,
    root_gauge_factory_proxy,
    alice,
    bob,
    charlie,
    chain,
):

    default_ownership_admin = root_gauge_factory_proxy.ownership_admin()
    default_emergency_admin = root_gauge_factory_proxy.emergency_admin()

    # alice deployed the factory and set herself as the owner of the factory contract
    assert root_gauge_factory.owner() == alice

    # alice is the only one who can kill gauges
    root_gauge.set_killed(True, {"from": alice})
    assert root_gauge.is_killed()
    assert root_gauge.inflation_params()[0] == 0  # inflation rate of root gauge should be 0
    chain.undo()

    # proxy cannot kill gauges yet, and neither can alice do it through the proxy:
    for unauthorised_admins in [
        default_emergency_admin,
        default_ownership_admin,
        alice,
    ]:
        with brownie.reverts():
            root_gauge_factory_proxy.set_killed(root_gauge, True, {"from": unauthorised_admins})

    # so transfer root gauge factory ownership to proxy:
    root_gauge_factory.commit_transfer_ownership(root_gauge_factory_proxy, {"from": alice})
    root_gauge_factory_proxy.accept_transfer_ownership(root_gauge_factory, {"from": bob})

    # only proxy admins can kill a gauge:
    for authorised_admin in [default_emergency_admin, default_ownership_admin]:
        root_gauge_factory_proxy.set_killed(root_gauge, True, {"from": authorised_admin})
        assert root_gauge.is_killed()
        if root_gauge == root_gauge:
            assert root_gauge.inflation_params()[0] == 0  # inflation rate of root gauge should be 0
        chain.undo()

    # unauthorised accounts cannot do so:
    for unauthorised_acct in [alice, bob, charlie]:
        with brownie.reverts():
            root_gauge_factory_proxy.set_killed(root_gauge, True, {"from": unauthorised_acct})


def test_set_bridger(root_gauge_factory, root_gauge_factory_proxy, alice, bob, chain):

    default_ownership_admin = root_gauge_factory_proxy.ownership_admin()
    default_emergency_admin = root_gauge_factory_proxy.emergency_admin()

    assert root_gauge_factory.owner() == alice
    manager = root_gauge_factory_proxy.manager()
    # proxy cannot set bridger yet:
    for admin in [manager, default_ownership_admin]:
        with brownie.reverts():
            root_gauge_factory_proxy.set_bridger(
                root_gauge_factory, chain.id, ETH_ADDRESS, {"from": admin}
            )

    # so transfer root gauge factory ownership to proxy:
    root_gauge_factory.commit_transfer_ownership(root_gauge_factory_proxy, {"from": alice})
    root_gauge_factory_proxy.accept_transfer_ownership(root_gauge_factory, {"from": bob})

    for admin in [manager, default_ownership_admin]:
        root_gauge_factory_proxy.set_bridger(
            root_gauge_factory, chain.id, ETH_ADDRESS, {"from": admin}
        )
        assert root_gauge_factory.get_bridger(chain.id) == ETH_ADDRESS
        chain.undo()

    # emergency admin cannot set bridger:
    with brownie.reverts():
        root_gauge_factory_proxy.set_bridger(
            root_gauge_factory, chain.id, ETH_ADDRESS, {"from": default_emergency_admin}
        )

    # but emergency admin can set itself (or anyone) as manager and change bridger:
    root_gauge_factory_proxy.set_manager(default_emergency_admin, {"from": default_emergency_admin})
    root_gauge_factory_proxy.set_bridger(
        root_gauge_factory, chain.id, ETH_ADDRESS, {"from": default_emergency_admin}
    )
    assert root_gauge_factory.get_bridger(chain.id) == ETH_ADDRESS


def test_set_implementation(root_gauge_factory, root_gauge_factory_proxy, alice, bob, chain):

    default_ownership_admin = root_gauge_factory_proxy.ownership_admin()
    default_emergency_admin = root_gauge_factory_proxy.emergency_admin()

    assert root_gauge_factory.owner() == alice
    manager = root_gauge_factory_proxy.manager()
    # proxy cannot set gauge implementation contract yet:
    for admin in [manager, default_ownership_admin]:
        with brownie.reverts():
            root_gauge_factory_proxy.set_implementation(
                root_gauge_factory, ETH_ADDRESS, {"from": admin}
            )

    # so transfer root gauge factory ownership to proxy:
    root_gauge_factory.commit_transfer_ownership(root_gauge_factory_proxy, {"from": alice})
    root_gauge_factory_proxy.accept_transfer_ownership(root_gauge_factory, {"from": bob})

    for admin in [manager, default_ownership_admin]:
        root_gauge_factory_proxy.set_implementation(
            root_gauge_factory, ETH_ADDRESS, {"from": admin}
        )
        assert root_gauge_factory.get_implementation() == ETH_ADDRESS
        chain.undo()

    # emergency admin cannot set gauge implementation:
    with brownie.reverts():
        root_gauge_factory_proxy.set_implementation(
            root_gauge_factory, ETH_ADDRESS, {"from": default_emergency_admin}
        )

    # but emergency admin can set itself (or anyone) as manager and change implementation:
    root_gauge_factory_proxy.set_manager(default_emergency_admin, {"from": default_emergency_admin})
    root_gauge_factory_proxy.set_implementation(
        root_gauge_factory, ETH_ADDRESS, {"from": default_emergency_admin}
    )
    assert root_gauge_factory.get_implementation() == ETH_ADDRESS


def test_set_call_proxy(root_gauge_factory, root_gauge_factory_proxy, alice, bob, chain):

    default_ownership_admin = root_gauge_factory_proxy.ownership_admin()
    default_emergency_admin = root_gauge_factory_proxy.emergency_admin()

    assert root_gauge_factory.owner() == alice
    manager = root_gauge_factory_proxy.manager()
    # proxy cannot set call proxy yet (only possible by factory owner):
    for admin in [manager, default_ownership_admin]:
        with brownie.reverts():
            root_gauge_factory_proxy.set_call_proxy(
                root_gauge_factory, ETH_ADDRESS, {"from": admin}
            )

    # so transfer root gauge factory ownership to proxy:
    root_gauge_factory.commit_transfer_ownership(root_gauge_factory_proxy, {"from": alice})
    root_gauge_factory_proxy.accept_transfer_ownership(root_gauge_factory, {"from": bob})

    for admin in [manager, default_ownership_admin]:
        root_gauge_factory_proxy.set_call_proxy(root_gauge_factory, ETH_ADDRESS, {"from": admin})
        assert root_gauge_factory.call_proxy() == ETH_ADDRESS
        chain.undo()

    # emergency admin cannot set call proxy:
    with brownie.reverts():
        root_gauge_factory_proxy.set_call_proxy(
            root_gauge_factory, ETH_ADDRESS, {"from": default_emergency_admin}
        )

    # but emergency admin can set itself (or anyone) as manager and
    # change the gauge factory's call proxy
    root_gauge_factory_proxy.set_manager(default_emergency_admin, {"from": default_emergency_admin})
    root_gauge_factory_proxy.set_call_proxy(
        root_gauge_factory, ETH_ADDRESS, {"from": default_emergency_admin}
    )
    assert root_gauge_factory.call_proxy() == ETH_ADDRESS
