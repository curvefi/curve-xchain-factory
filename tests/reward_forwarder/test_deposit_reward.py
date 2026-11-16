import brownie
import pytest

WEEK = 86400 * 7


@pytest.fixture(scope="module", autouse=True)
def setup(alice, bob, charlie, child_gauge, reward_token, lp_token):

    lp_token.approve(child_gauge, 10**21, {"from": alice})
    lp_token._mint_for_testing(alice, 10**21, {"from": alice})
    child_gauge.deposit(10**21, {"from": alice})

    reward_token._mint_for_testing(charlie, 10**26, {"from": alice})
    child_gauge.set_manager(bob, {"from": alice})


@pytest.fixture(scope="module", autouse=False)
def setup_with_deposited_rewards(alice, bob, charlie, reward_forwarder, child_gauge, reward_token):

    child_gauge.add_reward(reward_token, reward_forwarder, {"from": bob})
    reward_token.transfer(reward_forwarder, 10**20, {"from": charlie})

    reward_forwarder.allow(reward_token, {"from": alice})
    reward_forwarder.deposit_reward_token(reward_token, {"from": charlie})


def test_reward_deposit(alice, bob, charlie, child_gauge, reward_forwarder, reward_token):

    reward_forwarder.allow(reward_token, {"from": alice})
    child_gauge.add_reward(reward_token, reward_forwarder, {"from": bob})
    reward_token.transfer(reward_forwarder, 10**20, {"from": charlie})
    reward_forwarder.deposit_reward_token(reward_token, {"from": charlie})

    assert reward_token.balanceOf(child_gauge) == 10**20
    assert child_gauge.reward_data(reward_token)["rate"] > 0


def test_reward_deposit_reverts_without_allowance(
    bob, charlie, child_gauge, reward_forwarder, reward_token
):

    reward_token.transfer(reward_forwarder, 10**20, {"from": charlie})
    child_gauge.add_reward(reward_token, reward_forwarder, {"from": bob})

    # empty reward_forwarder cannot transfer tokens unless `allow` is called
    with brownie.reverts():
        reward_forwarder.deposit_reward_token(reward_token, {"from": charlie})


def test_reward_deposit_reverts_with_unauthorised_distributor(
    alice, charlie, reward_forwarder, reward_token
):

    reward_forwarder.allow(reward_token, {"from": alice})
    reward_token.transfer(reward_forwarder, 10**20, {"from": charlie})

    # reward_forwarder cannot deposit unless it is added as a distributor for that token
    # in the gauge contract
    with brownie.reverts():
        reward_forwarder.deposit_reward_token(reward_token, {"from": charlie})


def test_reward_deposit_revert_for_unauthorised_token(
    alice, bob, charlie, child_gauge, reward_forwarder, reward_token, unauthorised_token
):

    unauthorised_token._mint_for_testing(charlie, 10**26, {"from": alice})

    reward_forwarder.allow(reward_token, {"from": alice})
    reward_forwarder.allow(unauthorised_token, {"from": alice})

    # only add one token to gauge rewards
    child_gauge.add_reward(reward_token, reward_forwarder, {"from": bob})

    reward_token.transfer(reward_forwarder, 10**20, {"from": charlie})
    unauthorised_token.transfer(reward_forwarder, 10**20, {"from": charlie})

    with brownie.reverts():
        reward_forwarder.deposit_reward_token(unauthorised_token, {"from": charlie})


def test_empty_forward_keeps_schedule(
    alice,
    bob,
    charlie,
    child_gauge,
    chain,
    reward_forwarder,
    reward_token,
    setup_with_deposited_rewards,
):

    chain.sleep(WEEK // 2)
    rate = child_gauge.reward_data(reward_token)["rate"]
    period_finish = child_gauge.reward_data(reward_token)["period_finish"]

    # reward forwarder has zero balance: nothing is deposited, the distribution is not restarted
    reward_forwarder.deposit_reward_token(reward_token, {"from": charlie})

    assert child_gauge.reward_data(reward_token)["rate"] == rate
    assert child_gauge.reward_data(reward_token)["period_finish"] == period_finish

    # check alice's balance before and after claims:
    assert reward_token.balanceOf(alice) == 0
    child_gauge.claim_rewards({"from": alice})
    assert reward_token.balanceOf(alice) > 0


def test_forwarder_with_gauge_tokens_receives_no_rewards(
    alice,
    bob,
    charlie,
    child_gauge,
    chain,
    reward_forwarder,
    reward_token,
    setup_with_deposited_rewards,
):

    child_gauge.transfer(reward_forwarder, 10**20, {"from": alice})
    chain.sleep(WEEK // 2)

    # forwarding does not claim the forwarder's own rewards
    reward_token.transfer(reward_forwarder, 10**20, {"from": charlie})
    reward_forwarder.deposit_reward_token(reward_token, {"from": charlie})

    assert reward_token.balanceOf(reward_forwarder) == 0
    assert reward_token.balanceOf(child_gauge) == 2 * 10**20
    assert child_gauge.claimable_reward(reward_forwarder, reward_token) > 0


def test_reward_deposit_is_capped(
    alice, bob, chain, child_gauge, reward_forwarder, reward_token
):
    cap = 2**96
    reward_forwarder.allow(reward_token, {"from": alice})
    child_gauge.add_reward(reward_token, reward_forwarder, {"from": bob})
    reward_token._mint_for_testing(reward_forwarder, cap + 10**24, {"from": alice})

    # only what fits under the gauge's cap is forwarded, the rest stays
    reward_forwarder.deposit_reward_token(reward_token, {"from": alice})
    assert reward_token.balanceOf(child_gauge) == cap
    assert reward_token.balanceOf(reward_forwarder) == 10**24

    # no room: nothing is forwarded, the call does not revert and keeps the schedule
    period_finish = child_gauge.reward_data(reward_token)["period_finish"]
    reward_forwarder.deposit_reward_token(reward_token, {"from": alice})
    assert reward_token.balanceOf(reward_forwarder) == 10**24
    assert child_gauge.reward_data(reward_token)["period_finish"] == period_finish

    # distribution frees room once the gauge is checkpointed (any deposit, withdrawal or claim)
    chain.sleep(WEEK // 2)
    child_gauge.claim_rewards({"from": alice})
    reward_forwarder.deposit_reward_token(reward_token, {"from": alice})
    assert reward_token.balanceOf(reward_forwarder) == 0
    assert child_gauge.reward_remaining(reward_token) <= cap
