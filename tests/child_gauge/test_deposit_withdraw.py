import brownie
import pytest


@pytest.fixture(scope="module", autouse=True)
def deposit_setup(accounts, child_gauge, lp_token):
    lp_token._mint_for_testing(accounts[0], 10 ** 24, {"from": accounts[0]})
    lp_token.approve(child_gauge, 2 ** 256 - 1, {"from": accounts[0]})


def test_deposit(accounts, child_gauge, lp_token):
    balance = lp_token.balanceOf(accounts[0])
    child_gauge.deposit(100000, {"from": accounts[0]})

    assert lp_token.balanceOf(child_gauge) == 100000
    assert lp_token.balanceOf(accounts[0]) == balance - 100000
    assert child_gauge.totalSupply() == 100000
    assert child_gauge.balanceOf(accounts[0]) == 100000


def test_deposit_zero(accounts, child_gauge, lp_token):
    balance = lp_token.balanceOf(accounts[0])
    child_gauge.deposit(0, {"from": accounts[0]})

    assert lp_token.balanceOf(child_gauge) == 0
    assert lp_token.balanceOf(accounts[0]) == balance
    assert child_gauge.totalSupply() == 0
    assert child_gauge.balanceOf(accounts[0]) == 0


def test_deposit_insufficient_balance(accounts, child_gauge, lp_token):
    with brownie.reverts():
        child_gauge.deposit(100000, {"from": accounts[1]})


def test_withdraw(accounts, child_gauge, lp_token):
    balance = lp_token.balanceOf(accounts[0])

    child_gauge.deposit(100000, {"from": accounts[0]})
    child_gauge.withdraw(100000, {"from": accounts[0]})

    assert lp_token.balanceOf(child_gauge) == 0
    assert lp_token.balanceOf(accounts[0]) == balance
    assert child_gauge.totalSupply() == 0
    assert child_gauge.balanceOf(accounts[0]) == 0


def test_withdraw_zero(accounts, child_gauge, lp_token):
    balance = lp_token.balanceOf(accounts[0])
    child_gauge.deposit(100000, {"from": accounts[0]})
    child_gauge.withdraw(0, {"from": accounts[0]})

    assert lp_token.balanceOf(child_gauge) == 100000
    assert lp_token.balanceOf(accounts[0]) == balance - 100000
    assert child_gauge.totalSupply() == 100000
    assert child_gauge.balanceOf(accounts[0]) == 100000


def test_withdraw_new_epoch(accounts, chain, child_gauge, lp_token):
    balance = lp_token.balanceOf(accounts[0])

    child_gauge.deposit(100000, {"from": accounts[0]})
    chain.sleep(86400 * 400)
    child_gauge.withdraw(100000, {"from": accounts[0]})

    assert lp_token.balanceOf(child_gauge) == 0
    assert lp_token.balanceOf(accounts[0]) == balance
    assert child_gauge.totalSupply() == 0
    assert child_gauge.balanceOf(accounts[0]) == 0
