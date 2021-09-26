import math

import brownie
import pytest
from brownie import Contract

REWARD = 10 ** 21
WEEK = 86400 * 7


@pytest.fixture(scope="module")
def child_streamer(alice, child_factory, child_streamer_implementation, ChildChainStreamer):
    child_factory.set_implementation(child_streamer_implementation, {"from": alice})
    instance = child_factory.deploy_streamer(alice, {"from": alice}).return_value
    return Contract.from_abi("Child Chain Streamer Instance", instance, ChildChainStreamer.abi)


def test_initialized_storage(alice, child_factory, child_streamer):
    assert child_streamer.factory() == child_factory
    assert child_streamer.deployer() == alice
    assert child_streamer.receiver() == alice

    assert child_streamer.rate() == 0
    assert child_streamer.period_finish() == 0
    assert child_streamer.last_update() == 0
    assert child_streamer.reward_received() == 0
    assert child_streamer.reward_paid() == 0


def test_reinitialization_impossible(alice, child_streamer):
    with brownie.reverts():
        child_streamer.initialize(alice, alice, {"from": alice})


def test_set_receiver(alice, bob, child_streamer):
    child_streamer.set_receiver(bob, {"from": alice})

    assert child_streamer.receiver() == bob


def test_set_receiver_only_factory_owner(bob, child_streamer):
    with brownie.reverts():
        child_streamer.set_receiver(bob, {"from": bob})


def test_initial_notify(alice, child_streamer, reward_token):
    reward_token._mint_for_testing(child_streamer, REWARD, {"from": alice})
    tx = child_streamer.notify({"from": alice})

    assert child_streamer.rate() == REWARD // WEEK
    assert child_streamer.period_finish() == tx.timestamp + WEEK
    assert child_streamer.last_update() == tx.timestamp
    assert child_streamer.reward_received() == REWARD
    assert child_streamer.reward_paid() == 0


def test_reward_evenly_distributed(alice, chain, child_streamer, reward_token):
    reward_token._mint_for_testing(child_streamer, REWARD, {"from": alice})
    child_streamer.notify({"from": alice})

    rate = REWARD // WEEK

    distributed = 0
    for _ in range(7):
        # sleep for a day
        chain.sleep(86400)
        child_streamer.get_reward({"from": alice})

        distributed += rate * (WEEK // 7)
        assert math.isclose(child_streamer.reward_paid(), distributed, rel_tol=0.0001)


def test_notify_mid_distribution(alice, chain, child_streamer, reward_token):
    reward_token._mint_for_testing(child_streamer, REWARD, {"from": alice})
    child_streamer.notify({"from": alice})

    chain.sleep(WEEK // 2)

    reward_token._mint_for_testing(child_streamer, REWARD, {"from": alice})
    tx = child_streamer.notify({"from": alice})

    assert math.isclose(child_streamer.rate(), (REWARD // 2 + REWARD) // WEEK, rel_tol=0.0001)
    assert child_streamer.period_finish() == tx.timestamp + WEEK
    assert child_streamer.last_update() == tx.timestamp
    assert child_streamer.reward_received() == REWARD * 2
    assert math.isclose(child_streamer.reward_paid(), REWARD // 2, rel_tol=0.0001)


def test_notify_post_distribution(alice, chain, child_streamer, reward_token):
    reward_token._mint_for_testing(child_streamer, REWARD, {"from": alice})
    child_streamer.notify({"from": alice})

    chain.sleep(WEEK + 1)

    # below threshold but past distribution
    new_amount = 10 ** 20
    reward_token._mint_for_testing(child_streamer, new_amount, {"from": alice})
    tx = child_streamer.notify({"from": alice})

    assert child_streamer.rate() == new_amount // WEEK
    assert child_streamer.period_finish() == tx.timestamp + WEEK
    assert child_streamer.last_update() == tx.timestamp
    assert child_streamer.reward_received() == REWARD + new_amount
    assert math.isclose(child_streamer.reward_paid(), REWARD)


def test_notify_mid_distribution_fail_threshold_not_met(alice, chain, child_streamer, reward_token):
    reward_token._mint_for_testing(child_streamer, REWARD, {"from": alice})
    child_streamer.notify({"from": alice})

    chain.sleep(WEEK // 2)

    reward_token._mint_for_testing(child_streamer, 10 ** 20, {"from": alice})
    with brownie.reverts():
        child_streamer.notify({"from": alice})
