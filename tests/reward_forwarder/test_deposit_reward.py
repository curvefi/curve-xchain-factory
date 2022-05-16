import pytest
import brownie

WEEK = 86400 * 7


def test_reward_deposit(alice, bob, charlie, child_gauge, reward_forwarder, reward_token):

    reward_token._mint_for_testing(charlie, 10 ** 26, {"from": alice})
    reward_forwarder.allow(reward_token, {"from": alice})

    child_gauge.set_manager(bob, {"from": alice})
    child_gauge.add_reward(reward_token, reward_forwarder, {"from": bob})

    reward_token.transfer(reward_forwarder, 10 ** 20, {"from": charlie})
    reward_forwarder.deposit_reward_token(reward_token, {"from": charlie})

    assert reward_token.balanceOf(child_gauge) == 10 ** 20


def test_reward_token_approval(alice, bob, charlie, child_gauge, reward_forwarder, reward_token):

    reward_token._mint_for_testing(charlie, 10 ** 26, {"from": alice})
    reward_token.transfer(reward_forwarder, 10 ** 20, {"from": charlie})

    child_gauge.set_manager(bob, {"from": alice})
    child_gauge.add_reward(reward_token, reward_forwarder, {"from": bob})

    # empty reward_forwarder cannot transfer tokens unless `allow` is called
    with brownie.reverts():
        reward_forwarder.deposit_reward_token(reward_token, {"from": charlie})


def test_unauthorised_distributor(alice, charlie, reward_forwarder, reward_token):

    reward_token._mint_for_testing(charlie, 10 ** 26, {"from": alice})
    reward_forwarder.allow(reward_token, {"from": alice})
    reward_token.transfer(reward_forwarder, 10 ** 20, {"from": charlie})

    # reward_forwarder cannot deposit unless it is added as a distributor for that token
    # in the gauge contract
    with brownie.reverts():
        reward_forwarder.deposit_reward_token(reward_token, {"from": charlie})


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

    with brownie.reverts():
        reward_forwarder.deposit_reward_token(unauthorised_token, {"from": charlie})


def test_zero_reward_rate_claims(
    alice, bob, charlie, child_gauge, chain, reward_forwarder, reward_token, lp_token
):

    # mint lptokens and deposit into gauge:
    lp_token.approve(child_gauge, 10 ** 21, {"from": alice})
    lp_token._mint_for_testing(alice, 10 ** 21, {"from": alice})
    child_gauge.deposit(10 ** 21, {"from": alice})

    # mint reward tokens and approve transfers for RewardForwarder:
    reward_token._mint_for_testing(charlie, 10 ** 26, {"from": alice})
    reward_forwarder.allow(reward_token, {"from": alice})

    # set gauge managers:
    child_gauge.set_manager(bob, {"from": alice})
    child_gauge.add_reward(reward_token, reward_forwarder, {"from": bob})

    # deposit rewards and check if claimable reward token rate is non-zero:
    reward_token.transfer(reward_forwarder, 10 ** 20, {"from": charlie})
    reward_forwarder.deposit_reward_token(reward_token, {"from": charlie})
    assert reward_token.balanceOf(reward_forwarder) == 0  # no tokens in the reward forwarder
    assert child_gauge.reward_data(reward_token)[2] > 0  # token distribution rate is non-zero

    # sleep for a week until after period finish:
    chain.sleep(WEEK + 1)  # sleep for 1 week and 1 second
    assert chain.time() > child_gauge.reward_data(reward_token)[1]  # `period_end` reached

    # transferring zero reward tokens: this will make reward_token distribution rate zero
    reward_forwarder.deposit_reward_token(reward_token, {"from": charlie})
    assert child_gauge.reward_data(reward_token)[2] == 0  # token distribution rate becomes zero

    # check alice's balance before and after claims:
    assert reward_token.balanceOf(alice) == 0
    child_gauge.claim_rewards({"from": alice})
    assert reward_token.balanceOf(alice) > 0  # even if rate is zero, user can claim.
