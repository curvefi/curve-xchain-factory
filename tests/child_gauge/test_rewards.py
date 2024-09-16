import brownie
from brownie.test import given, strategy
from hypothesis import settings

WEEK = 86400 * 7


def test_only_manager_or_factory_owner(alice, bob, charlie, chain, child_gauge, reward_token):
    child_gauge.set_manager(bob, {"from": alice})

    for acct in [alice, bob]:
        child_gauge.add_reward(reward_token, charlie, {"from": acct})
        chain.undo()

    with brownie.reverts():
        child_gauge.add_reward(reward_token, charlie, {"from": charlie})


def test_add_reward(alice, charlie, child_gauge, reward_token):
    child_gauge.add_reward(reward_token, charlie, {"from": alice})
    assert child_gauge.reward_count() == 1
    assert child_gauge.reward_data(reward_token) == (
        charlie,  # distributor: address
        0,  # period_finish: uint256
        0,  # rate: uint256
        0,  # last_update: uint256
        0,  # integral: uint256
    )


def test_set_reward_distributor_admin_only(accounts, chain, reward_token, child_gauge):
    child_gauge.set_manager(accounts[1], {"from": accounts[0]})
    child_gauge.add_reward(reward_token, accounts[2], {"from": accounts[0]})

    for i in range(3):
        child_gauge.set_reward_distributor(reward_token, accounts[-1], {"from": accounts[i]})
        assert child_gauge.reward_data(reward_token)["distributor"] == accounts[-1]
        chain.undo()

    with brownie.reverts():
        child_gauge.set_reward_distributor(reward_token, accounts[-1], {"from": accounts[3]})


def test_deposit_reward_token(alice, child_gauge, reward_token):
    amount = 10 ** 26
    reward_token._mint_for_testing(alice, amount, {"from": alice})
    reward_token.approve(child_gauge, 2**256 - 1, {"from": alice})

    child_gauge.add_reward(reward_token, alice, {"from": alice})
    tx = child_gauge.deposit_reward_token(reward_token, amount, {"from": alice})

    reward_data = [
        alice,  # distributor: address
        tx.timestamp + WEEK,  # period_finish: uint256
        amount // WEEK,  # rate: uint256
        tx.timestamp,  # last_update: uint256
        0,  # integral: uint256
    ]
    assert child_gauge.reward_data(reward_token) == reward_data

    # Increase rate
    amount += 10 ** 18
    reward_token._mint_for_testing(alice, 10 ** 18, {"from": alice})
    tx = child_gauge.deposit_reward_token(reward_token, 10 ** 18, {"from": alice})

    reward_data = [
        alice,  # distributor: address
        tx.timestamp + WEEK,  # period_finish: uint256
        amount // WEEK,  # rate: uint256
        tx.timestamp,  # last_update: uint256
        0,  # integral: uint256
    ]
    assert child_gauge.reward_data(reward_token) == reward_data

    # Increase period
    tx = child_gauge.deposit_reward_token(reward_token, 0, 2 * WEEK, {"from": alice})

    reward_data = [
        alice,  # distributor: address
        tx.timestamp + 2 * WEEK,  # period_finish: uint256
        amount // (2 * WEEK),  # rate: uint256
        tx.timestamp,  # last_update: uint256
        0,  # integral: uint256
    ]
    assert child_gauge.reward_data(reward_token) == reward_data

    # Decrease period
    tx = child_gauge.deposit_reward_token(reward_token, 0, WEEK // 2, {"from": alice})

    reward_data = [
        alice,  # distributor: address
        tx.timestamp + WEEK // 2,  # period_finish: uint256
        amount // (WEEK // 2),  # rate: uint256
        tx.timestamp,  # last_update: uint256
        0,  # integral: uint256
    ]
    assert child_gauge.reward_data(reward_token) == reward_data


def test_deposit_reward_token(alice, child_gauge, reward_token):
    child_gauge.add_reward(reward_token, alice, {"from": alice})
    with brownie.reverts():
        child_gauge.deposit_reward_token(reward_token, 0, WEEK * 3 // 7 - 1, {"from": alice})
    with brownie.reverts():
        child_gauge.deposit_reward_token(reward_token, 0, WEEK * 4 * 12 + 1, {"from": alice})


@given(
    lp_amount=strategy('uint256', min_value=1, max_value=10 ** 9),
    delta=strategy('uint256', min_value=1, max_value=10 ** 6),
)
@settings(max_examples=20)
def test_reward_remaining(alice, bob, charlie, child_gauge, reward_token, lp_token, chain, lp_amount, delta):
    lp_token._mint_for_testing(alice, lp_amount * 10 ** 18, {"from": alice})
    lp_token.approve(child_gauge, lp_amount * 10 ** 18, {"from": alice})
    child_gauge.deposit(lp_amount * 10 ** 18, {"from": alice})

    reward_amount = lp_amount + delta
    reward_period = WEEK * 3 // 7  # minimum period
    child_gauge.add_reward(reward_token, bob, {"from": alice})
    reward_token._mint_for_testing(bob, reward_amount, {"from": bob})
    reward_token.approve(child_gauge, reward_amount, {"from": bob})
    child_gauge.deposit_reward_token(reward_token, reward_amount, reward_period, {"from": bob})

    checkpoints = 10
    for _ in range(checkpoints):
        chain.sleep(reward_period // checkpoints)
        child_gauge.claim_rewards({"from": alice})

    received = reward_token.balanceOf(alice)
    assert received == reward_amount - reward_amount % lp_amount

    remaining = child_gauge.reward_remaining(reward_token)
    assert remaining + received == reward_amount

    child_gauge.recover_remaining(reward_token, {"from": charlie})
    assert reward_token.balanceOf(bob) == remaining
