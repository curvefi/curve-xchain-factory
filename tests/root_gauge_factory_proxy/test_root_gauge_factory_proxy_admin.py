import brownie
import pytest
from brownie import ETH_ADDRESS


@pytest.fixture(scope="module")
def default_owner(root_gauge_factory_proxy):
    yield root_gauge_factory_proxy.ownership_admin()


@pytest.fixture(scope="module")
def default_e_admin(root_gauge_factory_proxy):
    yield root_gauge_factory_proxy.emergency_admin()


@pytest.fixture(scope="module")
def transfer_factory_ownership_to_proxy(alice, bob, root_gauge_factory, root_gauge_factory_proxy):
    root_gauge_factory.commit_transfer_ownership(root_gauge_factory_proxy, {"from": alice})
    root_gauge_factory_proxy.accept_transfer_ownership(root_gauge_factory, {"from": bob})


def test_set_manager_reverts_for_unauthorised_users(bob, charlie, root_gauge_factory_proxy):

    with brownie.reverts():
        root_gauge_factory_proxy.set_manager(charlie, {"from": bob})


def test_set_manager_success_for_authorised_users(
    alice, bob, root_gauge_factory_proxy, chain, default_owner, default_e_admin
):

    for acct in [alice, default_owner, default_e_admin]:
        root_gauge_factory_proxy.set_manager(bob, {"from": acct})
        assert root_gauge_factory_proxy.manager() == bob
        chain.undo()


def test_commit_admin_reverts_for_unauthorised_users(
    alice, bob, charlie, root_gauge_factory_proxy, default_e_admin
):

    for user in [alice, bob, charlie, default_e_admin]:
        with brownie.reverts():
            root_gauge_factory_proxy.commit_set_admins(bob, charlie, {"from": user})


@pytest.fixture(scope="module")
def test_commit_admin_successful_for_authorised_user(
    alice, bob, charlie, root_gauge_factory_proxy, default_owner
):

    root_gauge_factory_proxy.commit_set_admins(bob, charlie, {"from": default_owner})
    assert root_gauge_factory_proxy.future_ownership_admin() == bob
    assert root_gauge_factory_proxy.future_emergency_admin() == charlie


def test_accept_admin_revert_for_unauthorised_user(
    alice,
    charlie,
    root_gauge_factory_proxy,
    test_commit_admin_successful_for_authorised_user,
    default_owner,
    default_e_admin,
):

    for acct in [alice, charlie, default_owner, default_e_admin]:
        with brownie.reverts():
            root_gauge_factory_proxy.accept_set_admins({"from": acct})


def test_accept_admin_success_for_future_ownership_admin(
    root_gauge_factory_proxy, bob, charlie, test_commit_admin_successful_for_authorised_user
):

    root_gauge_factory_proxy.accept_set_admins({"from": bob})
    assert root_gauge_factory_proxy.ownership_admin() == bob
    assert root_gauge_factory_proxy.emergency_admin() == charlie


def test_commit_transfer_ownership_reverts_for_unauthorised_users(
    bob, charlie, root_gauge_factory, root_gauge_factory_proxy, default_owner, default_e_admin
):

    for acct in [bob, charlie, root_gauge_factory_proxy, default_owner, default_e_admin]:
        with brownie.reverts():
            root_gauge_factory_proxy.commit_transfer_ownership(
                root_gauge_factory, root_gauge_factory_proxy, {"from": acct}
            )


def test_commit_transfer_ownership_success_for_factory_owner(
    alice, root_gauge_factory, root_gauge_factory_proxy
):

    root_gauge_factory.commit_transfer_ownership(root_gauge_factory_proxy, {"from": alice})
    assert root_gauge_factory.future_owner() == root_gauge_factory_proxy
    assert root_gauge_factory.owner() == alice


def test_accept_transfer_ownership_success_for_authorised_admin(
    alice, bob, charlie, chain, root_gauge_factory, root_gauge_factory_proxy
):

    root_gauge_factory.commit_transfer_ownership(root_gauge_factory_proxy, {"from": alice})
    for acct in [alice, bob, charlie]:
        root_gauge_factory_proxy.accept_transfer_ownership(root_gauge_factory, {"from": acct})
        assert root_gauge_factory.owner() == root_gauge_factory_proxy
        chain.undo()


def test_set_killed_success_for_authorised_admin(
    chain,
    root_gauge,
    root_gauge_factory_proxy,
    transfer_factory_ownership_to_proxy,
    default_owner,
    default_e_admin,
):

    for authorised_admin in [default_owner, default_e_admin]:
        root_gauge_factory_proxy.set_killed(root_gauge, True, {"from": authorised_admin})
        assert root_gauge.is_killed()
        assert root_gauge.inflation_params()[0] == 0  # inflation rate of root gauge should be 0
        chain.undo()


def test_set_killed_reverts_for_unauthorised_users(
    alice, bob, charlie, root_gauge, root_gauge_factory_proxy, transfer_factory_ownership_to_proxy
):

    for unauthorised_acct in [alice, bob, charlie]:
        with brownie.reverts():
            root_gauge_factory_proxy.set_killed(root_gauge, True, {"from": unauthorised_acct})


def test_set_child_success_for_authorised_users(
    root_gauge_factory,
    root_gauge_factory_proxy,
    chain,
    transfer_factory_ownership_to_proxy,
    default_owner,
):

    manager = root_gauge_factory_proxy.manager()
    for acct in [manager, default_owner]:
        root_gauge_factory_proxy.set_child(
            root_gauge_factory, chain.id, ETH_ADDRESS, ETH_ADDRESS, ETH_ADDRESS, {"from": acct}
        )
        assert root_gauge_factory.get_bridger(chain.id) == ETH_ADDRESS
        assert root_gauge_factory.get_child_factory(chain.id) == ETH_ADDRESS
        assert root_gauge_factory.get_child_implementation(chain.id) == ETH_ADDRESS
        chain.undo()


def test_set_child_revert_for_unauthorised_users(
    bob,
    charlie,
    root_gauge_factory,
    root_gauge_factory_proxy,
    chain,
    transfer_factory_ownership_to_proxy,
    default_e_admin,
):

    for acct in [bob, charlie, default_e_admin]:
        with brownie.reverts():
            root_gauge_factory_proxy.set_child(
                root_gauge_factory, chain.id, ETH_ADDRESS, ETH_ADDRESS, ETH_ADDRESS, {"from": acct}
            )


def test_set_implementation_success_for_authorised_users(
    root_gauge_factory,
    root_gauge_factory_proxy,
    chain,
    transfer_factory_ownership_to_proxy,
    default_owner,
):

    manager = root_gauge_factory_proxy.manager()
    for acct in [manager, default_owner]:
        root_gauge_factory_proxy.set_implementation(root_gauge_factory, ETH_ADDRESS, {"from": acct})
        assert root_gauge_factory.get_implementation() == ETH_ADDRESS
        chain.undo()


def test_set_implementation_revert_for_unauthorised_users(
    bob,
    charlie,
    root_gauge_factory,
    root_gauge_factory_proxy,
    transfer_factory_ownership_to_proxy,
    default_e_admin,
):

    for acct in [bob, charlie, default_e_admin]:
        with brownie.reverts():
            root_gauge_factory_proxy.set_implementation(
                root_gauge_factory, ETH_ADDRESS, {"from": acct}
            )


def test_set_call_proxy_success_for_authorised_users(
    root_gauge_factory,
    root_gauge_factory_proxy,
    chain,
    transfer_factory_ownership_to_proxy,
    default_owner,
):

    manager = root_gauge_factory_proxy.manager()
    for acct in [manager, default_owner]:
        root_gauge_factory_proxy.set_call_proxy(root_gauge_factory, ETH_ADDRESS, {"from": acct})
        assert root_gauge_factory.call_proxy() == ETH_ADDRESS
        chain.undo()


def test_set_call_proxy_revert_for_unauthorised_users(
    bob,
    charlie,
    root_gauge_factory,
    root_gauge_factory_proxy,
    transfer_factory_ownership_to_proxy,
    default_e_admin,
):

    for acct in [bob, charlie, default_e_admin]:
        with brownie.reverts():
            root_gauge_factory_proxy.set_call_proxy(root_gauge_factory, ETH_ADDRESS, {"from": acct})
