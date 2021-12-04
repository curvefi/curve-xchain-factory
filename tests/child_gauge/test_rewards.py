import brownie


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
