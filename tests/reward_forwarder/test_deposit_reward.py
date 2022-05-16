import brownie


def test_deposit_reward_token(
    alice, bob, charlie, chain, child_gauge, reward_forwarder, reward_token
):

    reward_token._mint_for_testing(charlie, 10 ** 26, {"from": alice})
    chain.snapshot()

    # only reward_forwarder can deposit rewards so far, but just a sanity check:
    with brownie.reverts():
        child_gauge.deposit_reward_token(reward_token, 10 ** 26, {"from": alice})

    # empty reward_forwarder cannot transfer tokens unless `allow` is called
    with brownie.reverts():
        reward_token.transfer(reward_forwarder, 10 ** 20, {"from": bob})
        child_gauge.add_reward(reward_token, reward_forwarder, {"from": bob})
        reward_forwarder.deposit_reward_token(reward_token)
        chain.revert()

    # empty reward_forwarder cannot transfer tokens if it is empty
    with brownie.reverts():
        reward_forwarder.allow(reward_token, {"from": alice})
        child_gauge.add_reward(reward_token, reward_forwarder, {"from": bob})
        reward_forwarder.deposit_reward_token(reward_token),
        chain.revert()

    # reward_forwarder cannot deposit unless it is added as a distributor for that token
    # in the gauge contract
    with brownie.reverts():
        reward_forwarder.allow(reward_token, {"from": alice})
        reward_token.transfer(reward_forwarder, 10 ** 20, {"from": bob})
        reward_forwarder.deposit_reward_token(reward_token)
        chain.revert()

    # working flow:
    reward_forwarder.allow(reward_token, {"from": alice})
    child_gauge.set_manager(bob, {"from": alice})
    child_gauge.add_reward(reward_token, reward_forwarder, {"from": bob})
    reward_token.transfer(reward_forwarder, 10 ** 20, {"from": charlie})
    reward_forwarder.deposit_reward_token(reward_token)

    assert reward_token.balanceOf(child_gauge) == 10 ** 20
