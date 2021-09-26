import pytest
from brownie import ETH_ADDRESS, compile_source
from brownie_tokens import ERC20


@pytest.fixture(scope="session")
def dao_contracts(pm):
    return pm("curvefi/curve-dao-contracts@1.3.0")


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


@pytest.fixture(scope="module")
def child_streamer_implementation(alice, ChildChainStreamer):
    return ChildChainStreamer.deploy({"from": alice})


@pytest.fixture(scope="module")
def token(alice, dao_contracts):
    return dao_contracts.ERC20CRV.deploy("Curve DAO Token", "CRV", 18, {"from": alice})


@pytest.fixture(scope="module")
def voting_escrow(alice, token, dao_contracts):
    return dao_contracts.VotingEscrow.deploy(
        token, "Voting-escrowed CRV", "veCRV", "veCRV", {"from": alice}
    )


@pytest.fixture(scope="module")
def gauge_controller(alice, dao_contracts, token, voting_escrow):
    return dao_contracts.GaugeController.deploy(token, voting_escrow, {"from": alice})


@pytest.fixture(scope="module")
def minter(alice, chain, dao_contracts, gauge_controller, token):
    _minter = dao_contracts.Minter.deploy(token, gauge_controller, {"from": alice})

    token.set_minter(_minter, {"from": alice})
    chain.mine(timedelta=604800)
    token.update_mining_parameters({"from": alice})

    return _minter


@pytest.fixture(scope="module")
def anyswap_root_gauge_implementation(alice, minter, RootGaugeAnyswap):
    source = RootGaugeAnyswap._build["source"]
    for value in [minter.address, ETH_ADDRESS]:
        source = source.replace("ZERO_ADDRESS", value, 1)
    NewRootGaugeAnyswap = compile_source(source).Vyper
    return NewRootGaugeAnyswap.deploy({"from": alice})
