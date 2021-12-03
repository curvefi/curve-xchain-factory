import pytest
from hexbytes import HexBytes


@pytest.mark.parametrize("idx", range(5))
def test_initial_approval_is_zero(child_gauge, accounts, idx):
    assert child_gauge.allowance(accounts[0], accounts[idx]) == 0


def test_approve(child_gauge, accounts):
    child_gauge.approve(accounts[1], 10 ** 19, {"from": accounts[0]})

    assert child_gauge.allowance(accounts[0], accounts[1]) == 10 ** 19


def test_modify_approve(child_gauge, accounts):
    child_gauge.approve(accounts[1], 10 ** 19, {"from": accounts[0]})
    child_gauge.approve(accounts[1], 12345678, {"from": accounts[0]})

    assert child_gauge.allowance(accounts[0], accounts[1]) == 12345678


def test_revoke_approve(child_gauge, accounts):
    child_gauge.approve(accounts[1], 10 ** 19, {"from": accounts[0]})
    child_gauge.approve(accounts[1], 0, {"from": accounts[0]})

    assert child_gauge.allowance(accounts[0], accounts[1]) == 0


def test_approve_self(child_gauge, accounts):
    child_gauge.approve(accounts[0], 10 ** 19, {"from": accounts[0]})

    assert child_gauge.allowance(accounts[0], accounts[0]) == 10 ** 19


def test_only_affects_target(child_gauge, accounts):
    child_gauge.approve(accounts[1], 10 ** 19, {"from": accounts[0]})

    assert child_gauge.allowance(accounts[1], accounts[0]) == 0


def test_returns_true(child_gauge, accounts):
    tx = child_gauge.approve(accounts[1], 10 ** 19, {"from": accounts[0]})

    assert tx.trace[-1]["op"] == "RETURN"
    memory = HexBytes("".join(tx.trace[-1]["memory"]))
    length, offset = int(tx.trace[-1]["stack"][0], 16), int(tx.trace[-1]["stack"][1], 16)
    assert int.from_bytes(memory[offset : offset + length], "big") == 1


def test_approval_event_fires(accounts, child_gauge):
    tx = child_gauge.approve(accounts[1], 10 ** 19, {"from": accounts[0]})

    assert len(tx.events) == 1
    assert tx.events["Approval"].values() == [accounts[0], accounts[1], 10 ** 19]


def test_increase_allowance(accounts, child_gauge):
    child_gauge.approve(accounts[1], 100, {"from": accounts[0]})
    child_gauge.increaseAllowance(accounts[1], 403, {"from": accounts[0]})

    assert child_gauge.allowance(accounts[0], accounts[1]) == 503


def test_decrease_allowance(accounts, child_gauge):
    child_gauge.approve(accounts[1], 100, {"from": accounts[0]})
    child_gauge.decreaseAllowance(accounts[1], 34, {"from": accounts[0]})

    assert child_gauge.allowance(accounts[0], accounts[1]) == 66
