import pytest


@pytest.fixture(scope="module")
def root_chain_factory(alice, RootChainGaugeFactory):
    return RootChainGaugeFactory.deploy({"from": alice})


@pytest.fixture(scope="module")
def mock_root_gauge_implementation(alice, MockRootGauge):
    return MockRootGauge.deploy({"from": alice})
