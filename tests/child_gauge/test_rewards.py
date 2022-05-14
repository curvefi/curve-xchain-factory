import brownie

WEEK = 86400 * 7


def test_only_manager_or_factory_owner(alice, bob, charlie, chain, child_gauge, reward_token):
    child_gauge.set_manager(bob, {"from": alice})

    for acct in [alice, bob]:
        child_gauge.add_reward(reward_token, charlie, {"from": acct})
        chain.undo()

    with brownie.reverts():
        child_gauge.add_reward(reward_token, charlie, {"from": charlie})


def test_reward_data_updated(alice, charlie, child_gauge, reward_token):

    child_gauge.add_reward(reward_token, charlie, {"from": alice})
    expected_data = (charlie, 0, 0, 0, 0)

    assert child_gauge.reward_count() == 1
    assert child_gauge.reward_tokens(0) == reward_token
    assert child_gauge.reward_data(reward_token) == expected_data


def test_reverts_for_double_adding(alice, child_gauge, reward_token):
    child_gauge.add_reward(reward_token, alice, {"from": alice})

    with brownie.reverts():
        child_gauge.add_reward(reward_token, alice, {"from": alice})


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
    reward_token._mint_for_testing(alice, 10**26, {"from": alice})
    reward_token.approve(child_gauge, 2**256 - 1, {"from": alice})

    child_gauge.add_reward(reward_token, alice, {"from": alice})
    tx = child_gauge.deposit_reward_token(reward_token, 10**26, {"from": alice})

    expected = (alice, tx.timestamp + WEEK, 10**26 // WEEK, tx.timestamp, 0)
    assert child_gauge.reward_data(reward_token) == expected
