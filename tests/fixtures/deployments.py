import pytest


@pytest.fixture(scope="module")
def root_factory(alice, RootChainGaugeFactory):
    return RootChainGaugeFactory.deploy({"from": alice})


@pytest.fixture(scope="module")
def mock_root_gauge_implementation(alice, MockRootGauge):
    return MockRootGauge.deploy({"from": alice})


@pytest.fixture(scope="module")
def child_factory(alice, ChildChainStreamerFactory):
    return ChildChainStreamerFactory.deploy({"from": alice})


@pytest.fixture(scope="module")
def mock_child_streamer_implementation(alice, MockChildStreamer):
    return MockChildStreamer.deploy({"from": alice})
