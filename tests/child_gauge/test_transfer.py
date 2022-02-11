#!/usr/bin/python3
import brownie
import pytest
from hexbytes import HexBytes


@pytest.fixture(scope="module", autouse=True)
def setup(accounts, child_gauge, lp_token):
    lp_token._mint_for_testing(accounts[0], 10 ** 24, {"from": accounts[0]})
    lp_token.approve(child_gauge, 2 ** 256 - 1, {"from": accounts[0]})
    child_gauge.deposit(10 ** 18, {"from": accounts[0]})


def test_sender_balance_decreases(accounts, child_gauge):
    sender_balance = child_gauge.balanceOf(accounts[0])
    amount = sender_balance // 4

    child_gauge.transfer(accounts[1], amount, {"from": accounts[0]})

    assert child_gauge.balanceOf(accounts[0]) == sender_balance - amount


def test_receiver_balance_increases(accounts, child_gauge):
    receiver_balance = child_gauge.balanceOf(accounts[1])
    amount = child_gauge.balanceOf(accounts[0]) // 4

    child_gauge.transfer(accounts[1], amount, {"from": accounts[0]})

    assert child_gauge.balanceOf(accounts[1]) == receiver_balance + amount


def test_total_supply_not_affected(accounts, child_gauge):
    total_supply = child_gauge.totalSupply()
    amount = child_gauge.balanceOf(accounts[0])

    child_gauge.transfer(accounts[1], amount, {"from": accounts[0]})

    assert child_gauge.totalSupply() == total_supply


def test_returns_true(accounts, child_gauge):
    amount = child_gauge.balanceOf(accounts[0])
    tx = child_gauge.transfer(accounts[1], amount, {"from": accounts[0]})

    assert tx.trace[-1]["op"] == "RETURN"
    memory = HexBytes("".join(tx.trace[-1]["memory"]))
    length, offset = int(tx.trace[-1]["stack"][0], 16), int(tx.trace[-1]["stack"][1], 16)
    assert int.from_bytes(memory[offset : offset + length], "big") == 1


def test_transfer_full_balance(accounts, child_gauge):
    amount = child_gauge.balanceOf(accounts[0])
    receiver_balance = child_gauge.balanceOf(accounts[1])

    child_gauge.transfer(accounts[1], amount, {"from": accounts[0]})

    assert child_gauge.balanceOf(accounts[0]) == 0
    assert child_gauge.balanceOf(accounts[1]) == receiver_balance + amount


def test_transfer_zero_tokens(accounts, child_gauge):
    sender_balance = child_gauge.balanceOf(accounts[0])
    receiver_balance = child_gauge.balanceOf(accounts[1])

    child_gauge.transfer(accounts[1], 0, {"from": accounts[0]})

    assert child_gauge.balanceOf(accounts[0]) == sender_balance
    assert child_gauge.balanceOf(accounts[1]) == receiver_balance


def test_transfer_to_self(accounts, child_gauge):
    sender_balance = child_gauge.balanceOf(accounts[0])
    amount = sender_balance // 4

    child_gauge.transfer(accounts[0], amount, {"from": accounts[0]})

    assert child_gauge.balanceOf(accounts[0]) == sender_balance


def test_insufficient_balance(accounts, child_gauge):
    balance = child_gauge.balanceOf(accounts[0])

    with brownie.reverts():
        child_gauge.transfer(accounts[1], balance + 1, {"from": accounts[0]})


def test_transfer_event_fires(accounts, child_gauge):
    amount = child_gauge.balanceOf(accounts[0])
    tx = child_gauge.transfer(accounts[1], amount, {"from": accounts[0]})

    assert tx.events["Transfer"].values() == [accounts[0], accounts[1], amount]
