import brownie

WEEK = 86400 * 7


def test_only_manager_or_factory_owner(alice, bob, charlie, chain, child_gauge, reward_token):
    child_gauge.set_manager(bob, {"from": alice})

    for acct in [alice, bob]:
        child_gauge.add_reward(reward_token, charlie, {"from": acct})
        chain.undo()

    with brownie.reverts():
        child_gauge.add_reward(reward_token, charlie, {"from": charlie})


def test_add_reward(alice, charlie, child_gauge, reward_token, reward_token_8):
    reward_id = child_gauge.add_reward(reward_token, charlie, {"from": alice}).return_value
    assert child_gauge.reward_count() == 1
    assert child_gauge.reward_data(reward_id) == (
        reward_token,  # token: ERC20
        charlie,  # distributor: address
        0,  # period_finish: uint256
        0,  # rate: uint256
        0,  # last_update: uint256
        0,  # integral: uint256
        1,  # precision: uint256
    )

    reward_id = child_gauge.add_reward(reward_token_8, charlie, {"from": alice}).return_value
    assert child_gauge.reward_count() == 2
    assert child_gauge.reward_data(reward_id) == (
        reward_token_8,  # token: ERC20
        charlie,  # distributor: address
        0,  # period_finish: uint256
        0,  # rate: uint256
        0,  # last_update: uint256
        0,  # integral: uint256
        10 ** 10,  # precision: uint256
    )

    reward_id = child_gauge.add_reward(reward_token_8, charlie, 10 ** 4, {"from": alice}).return_value
    assert child_gauge.reward_count() == 3
    assert child_gauge.reward_data(reward_id) == (
        reward_token_8,  # token: ERC20
        charlie,  # distributor: address
        0,  # period_finish: uint256
        0,  # rate: uint256
        0,  # last_update: uint256
        0,  # integral: uint256
        10 ** 4,  # precision: uint256
    )


def test_set_reward_distributor_admin_only(accounts, chain, reward_token, child_gauge):
    child_gauge.set_manager(accounts[1], {"from": accounts[0]})
    reward_id = child_gauge.add_reward(reward_token, accounts[2], {"from": accounts[0]}).return_value

    for i in range(3):
        child_gauge.set_reward_distributor(reward_id, accounts[-1], {"from": accounts[i]})
        assert child_gauge.reward_data(reward_id)["distributor"] == accounts[-1]
        chain.undo()

    with brownie.reverts():
        child_gauge.set_reward_distributor(reward_id, accounts[-1], {"from": accounts[3]})


def test_deposit_reward_token(alice, child_gauge, reward_token):
    amount = 10 ** 26
    reward_token._mint_for_testing(alice, amount, {"from": alice})
    reward_token.approve(child_gauge, 2**256 - 1, {"from": alice})

    reward_id = child_gauge.add_reward(reward_token, alice, {"from": alice}).return_value
    tx = child_gauge.deposit_reward_token(reward_id, amount, {"from": alice})

    reward_data = [
        reward_token,  # token: ERC20
        alice,  # distributor: address
        tx.timestamp + WEEK,  # period_finish: uint256
        amount // WEEK,  # rate: uint256
        tx.timestamp,  # last_update: uint256
        0,  # integral: uint256
        1,  # precision: uint256
    ]
    assert child_gauge.reward_data(reward_id) == reward_data

    # Increase rate
    amount += 10 ** 18
    reward_token._mint_for_testing(alice, 10 ** 18, {"from": alice})
    tx = child_gauge.deposit_reward_token(reward_id, 10 ** 18, {"from": alice})

    reward_data = reward_data[:2] + [
        tx.timestamp + WEEK,  # period_finish: uint256
        amount // WEEK,  # rate: uint256, totalSupply == 0 not counted hence fail
        tx.timestamp,  # last_update: uint256
    ] + reward_data[5:]
    assert child_gauge.reward_data(reward_id) == reward_data

    # Increase period
    # _new_duration
    # _new_period_finish
    # Week period rekt allowed
    # longer period rekt forbidden
