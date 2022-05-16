import brownie


def test_reward_deposit(alice, bob, charlie, child_gauge, reward_forwarder, reward_token):

    reward_token._mint_for_testing(charlie, 10 ** 26, {"from": alice})

    reward_forwarder.allow(reward_token, {"from": alice})
    child_gauge.set_manager(bob, {"from": alice})
    child_gauge.add_reward(reward_token, reward_forwarder, {"from": bob})
    reward_token.transfer(reward_forwarder, 10 ** 20, {"from": charlie})
    reward_forwarder.deposit_reward_token(reward_token)

    assert reward_token.balanceOf(child_gauge) == 10 ** 20


def test_reward_token_approval(alice, bob, charlie, child_gauge, reward_forwarder, reward_token):

    reward_token._mint_for_testing(charlie, 10 ** 26, {"from": alice})
    reward_token.transfer(reward_forwarder, 10 ** 20, {"from": bob})
    child_gauge.set_manager(bob, {"from": alice})
    child_gauge.add_reward(reward_token, reward_forwarder, {"from": bob})

    # empty reward_forwarder cannot transfer tokens unless `allow` is called
    with brownie.reverts():
        reward_forwarder.deposit_reward_token(reward_token)


def test_insufficient_reward_token_balance(
    alice, bob, charlie, child_gauge, reward_forwarder, reward_token
):

    reward_token._mint_for_testing(charlie, 10 ** 26, {"from": alice})
    reward_forwarder.allow(reward_token, {"from": alice})
    child_gauge.add_reward(reward_token, reward_forwarder, {"from": bob})

    assert reward_token.balanceOf(reward_forwarder) == 0  # no tokens were sent to reward forwarder

    # empty reward_forwarder cannot transfer tokens if it is empty
    with brownie.reverts():
        reward_forwarder.deposit_reward_token(reward_token),


def test_unauthorised_distributor(alice, bob, charlie, child_gauge, reward_forwarder, reward_token):

    reward_token._mint_for_testing(charlie, 10 ** 26, {"from": alice})
    reward_forwarder.allow(reward_token, {"from": alice})
    reward_token.transfer(reward_forwarder, 10 ** 20, {"from": bob})

    # reward_forwarder cannot deposit unless it is added as a distributor for that token
    # in the gauge contract
    with brownie.reverts():
        reward_forwarder.deposit_reward_token(reward_token)


def test_unauthorised_reward_token_for_authorised_distributor(
    alice, bob, charlie, child_gauge, reward_forwarder, reward_token, unauthorised_token
):

    reward_token._mint_for_testing(charlie, 10 ** 26, {"from": alice})
    unauthorised_token._mint_for_testing(charlie, 10 ** 26, {"from": alice})

    reward_forwarder.allow(reward_token, {"from": alice})
    reward_forwarder.allow(unauthorised_token, {"from": alice})

    # only add one token to gauge rewards
    child_gauge.set_manager(bob, {"from": alice})
    child_gauge.add_reward(reward_token, reward_forwarder, {"from": bob})

    reward_token.transfer(reward_forwarder, 10 ** 20, {"from": charlie})
    unauthorised_token.transfer(reward_forwarder, 10 ** 20, {"from": charlie})
    reward_forwarder.deposit_reward_token(unauthorised_token)
