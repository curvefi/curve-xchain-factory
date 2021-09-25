import pytest
from brownie_tokens import ERC20


@pytest.fixture(scope="module")
def root_factory(alice, RootChainGaugeFactory):
    return RootChainGaugeFactory.deploy({"from": alice})


@pytest.fixture(scope="module")
def mock_root_gauge_implementation(alice, MockRootGauge):
    return MockRootGauge.deploy({"from": alice})


@pytest.fixture(scope="module")
def reward_token(alice):
    return ERC20(deployer=alice)


@pytest.fixture(scope="module")
def child_factory(alice, reward_token, ChildChainStreamerFactory):
    return ChildChainStreamerFactory.deploy(reward_token, {"from": alice})


@pytest.fixture(scope="module")
def mock_child_streamer_implementation(alice, MockChildStreamer):
    return MockChildStreamer.deploy({"from": alice})
