import pytest


@pytest.fixture(scope="module")
def root_chain_factory(alice, RootChainGaugeFactory):
    return RootChainGaugeFactory.deploy({"from": alice})
