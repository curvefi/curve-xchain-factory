import brownie
from brownie import ZERO_ADDRESS


def test_commit_transfer_ownership(alice, bob, child_factory):
    child_factory.commit_transfer_ownership(bob, {"from": alice})

    assert child_factory.future_owner() == bob


def test_commit_transfer_ownership_only_owner(bob, child_factory):
    with brownie.reverts("dev: owner only"):
        child_factory.commit_transfer_ownership(bob, {"from": bob})


def test_accept_transfer_ownership(alice, bob, child_factory):
    child_factory.commit_transfer_ownership(bob, {"from": alice})
    tx = child_factory.accept_transfer_ownership({"from": bob})

    assert child_factory.owner() == bob
    assert "OwnershipTransferred" in tx.events
    assert tx.events["OwnershipTransferred"] == dict(_owner=alice, _new_owner=bob)


def test_accept_transfer_ownership_only_future_owner(alice, bob, child_factory):
    child_factory.commit_transfer_ownership(bob, {"from": alice})

    with brownie.reverts("dev: new owner only"):
        child_factory.accept_transfer_ownership({"from": alice})


def test_set_implementation(alice, child_factory, mock_child_gauge_implementation):
    tx = child_factory.set_implementation(mock_child_gauge_implementation, {"from": alice})

    assert child_factory.get_implementation() == mock_child_gauge_implementation
    assert "ImplementationUpdated" in tx.events

    expected = dict(
        _implementation=ZERO_ADDRESS,
        _new_implementation=mock_child_gauge_implementation,
    )
    assert tx.events["ImplementationUpdated"] == expected


def test_set_implementation_only_owner(bob, child_factory, mock_child_gauge_implementation):
    with brownie.reverts():
        child_factory.set_implementation(mock_child_gauge_implementation, {"from": bob})
