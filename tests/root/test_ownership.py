import brownie
from brownie import ZERO_ADDRESS


def test_commit_transfer_ownership(alice, bob, root_factory):
    root_factory.commit_transfer_ownership(bob, {"from": alice})

    assert root_factory.future_owner() == bob


def test_commit_transfer_ownership_only_owner(bob, root_factory):
    with brownie.reverts("dev: owner only"):
        root_factory.commit_transfer_ownership(bob, {"from": bob})


def test_accept_transfer_ownership(alice, bob, root_factory):
    root_factory.commit_transfer_ownership(bob, {"from": alice})
    tx = root_factory.accept_transfer_ownership({"from": bob})

    assert root_factory.owner() == bob
    assert "OwnershipTransferred" in tx.events
    assert tx.events["OwnershipTransferred"] == dict(_owner=alice, _new_owner=bob)


def test_accept_transfer_ownership_only_future_owner(alice, bob, root_factory):
    root_factory.commit_transfer_ownership(bob, {"from": alice})

    with brownie.reverts("dev: new owner only"):
        root_factory.accept_transfer_ownership({"from": alice})


def test_set_implementation(alice, chain, root_factory, mock_root_gauge_implementation):
    tx = root_factory.set_implementation(chain.id, mock_root_gauge_implementation, {"from": alice})

    assert root_factory.get_implementation(chain.id) == mock_root_gauge_implementation
    assert "ImplementationUpdated" in tx.events

    expected = dict(
        _chain_id=chain.id,
        _implementation=ZERO_ADDRESS,
        _new_implementation=mock_root_gauge_implementation,
    )
    assert tx.events["ImplementationUpdated"] == expected


def test_set_implementation_only_owner(bob, chain, root_factory, mock_root_gauge_implementation):
    with brownie.reverts():
        root_factory.set_implementation(chain.id, mock_root_gauge_implementation, {"from": bob})
