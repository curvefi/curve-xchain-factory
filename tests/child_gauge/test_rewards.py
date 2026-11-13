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


def test_deposit_reward_token_cap(alice, child_gauge, reward_token):
    cap = 2 ** 96
    reward_token._mint_for_testing(alice, cap + 1, {"from": alice})
    reward_token.approve(child_gauge, 2 ** 256 - 1, {"from": alice})
    child_gauge.add_reward(reward_token, alice, {"from": alice})

    with brownie.reverts("Reward overflow"):
        child_gauge.deposit_reward_token(reward_token, cap + 1, {"from": alice})

    child_gauge.deposit_reward_token(reward_token, cap, {"from": alice})
    with brownie.reverts("Reward overflow"):
        child_gauge.deposit_reward_token(reward_token, 1, {"from": alice})


def _start_rewards(alice, chain, child_gauge, lp_token, tokens, amount=10 ** 21):
    lp_token._mint_for_testing(alice, 10 ** 18, {"from": alice})
    lp_token.approve(child_gauge, 10 ** 18, {"from": alice})
    child_gauge.deposit(10 ** 18, {"from": alice})

    for token in tokens:
        token._mint_for_testing(alice, amount, {"from": alice})
        token.approve(child_gauge, amount, {"from": alice})
        child_gauge.add_reward(token, alice, {"from": alice})
        child_gauge.deposit_reward_token(token, amount, {"from": alice})
    chain.sleep(WEEK + 1)


def test_claim_selected_rewards(
    alice, bob, chain, child_gauge, lp_token, reward_token, unauthorised_token
):
    other_token = unauthorised_token
    _start_rewards(alice, chain, child_gauge, lp_token, [reward_token, other_token])

    child_gauge.claim_rewards(alice, bob, [reward_token], {"from": alice})
    assert reward_token.balanceOf(bob) > 0
    assert other_token.balanceOf(bob) == 0

    pending = child_gauge.claimable_reward(alice, other_token)
    assert pending > 0

    child_gauge.claim_rewards(alice, bob, {"from": alice})
    assert other_token.balanceOf(bob) == pending


def test_set_reward_invalidated_admin_only(alice, bob, charlie, chain, child_gauge, reward_token):
    child_gauge.set_manager(bob, {"from": alice})

    with brownie.reverts():  # not a reward
        child_gauge.set_reward_invalidated(reward_token, True, {"from": alice})

    child_gauge.add_reward(reward_token, charlie, {"from": alice})
    for acct in [alice, bob]:
        child_gauge.set_reward_invalidated(reward_token, True, {"from": acct})
        assert child_gauge.invalidated_reward(reward_token)
        chain.undo()

    with brownie.reverts():
        child_gauge.set_reward_invalidated(reward_token, True, {"from": charlie})


def test_invalidated_reward_skipped_by_default(
    alice, bob, chain, child_gauge, lp_token, reward_token, unauthorised_token
):
    other_token = unauthorised_token
    _start_rewards(alice, chain, child_gauge, lp_token, [reward_token, other_token])
    child_gauge.set_reward_invalidated(other_token, True, {"from": alice})

    # skipped in default claims, keeps accruing
    child_gauge.claim_rewards(alice, bob, {"from": alice})
    child_gauge.withdraw(10 ** 17, True, {"from": alice})
    assert reward_token.balanceOf(bob) > 0
    assert other_token.balanceOf(alice) + other_token.balanceOf(bob) == 0

    pending = child_gauge.claimable_reward(alice, other_token)
    assert pending > 0

    # claimable explicitly
    child_gauge.claim_rewards(alice, bob, [other_token], {"from": alice})
    assert other_token.balanceOf(bob) == pending

    # reversible
    child_gauge.set_reward_invalidated(other_token, False, {"from": alice})
    assert not child_gauge.invalidated_reward(other_token)
