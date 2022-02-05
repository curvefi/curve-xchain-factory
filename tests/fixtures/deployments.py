import pytest
from brownie import Contract
from brownie_tokens import ERC20

# ANYCALL DEPLOYMENT


@pytest.fixture(scope="module")
def anycall(alice, AnyCallProxy):
    return AnyCallProxy.deploy(alice, 0, {"from": alice})


# CHILD CHAIN DEPLOYMENTS


@pytest.fixture(scope="module")
def child_crv_token(alice):
    return ERC20("Child Curve DAO Token", "cCRV", 18, deployer=alice)


@pytest.fixture(scope="module")
def child_gauge_factory(alice, anycall, child_crv_token, ChildGaugeFactory):
    factory = ChildGaugeFactory.deploy(anycall, child_crv_token, alice, {"from": alice})
    anycall.setWhitelist(factory, factory, 1, True, {"from": alice})
    return factory


@pytest.fixture(scope="module")
def lp_token(alice):
    return ERC20("Dummy LP Token", "dLP", 18, deployer=alice)


@pytest.fixture(scope="module")
def reward_token(alice):
    return ERC20("Dummy Reward Token", "dRT", 18, deployer=alice)


@pytest.fixture(scope="module")
def child_gauge_impl(alice, child_crv_token, ChildGauge, child_gauge_factory):
    impl = ChildGauge.deploy(child_crv_token, child_gauge_factory, {"from": alice})
    child_gauge_factory.set_implementation(impl, {"from": alice})
    return impl


@pytest.fixture(scope="module")
def child_gauge(alice, child_gauge_impl, child_gauge_factory, lp_token, ChildGauge):
    gauge_addr = child_gauge_factory.deploy_gauge(lp_token, 0x0, {"from": alice}).return_value
    return Contract.from_abi("Child Gauge", gauge_addr, ChildGauge.abi)


@pytest.fixture(scope="module")
def child_oracle(alice, anycall, ChildOracle):
    return ChildOracle.deploy(anycall, {"from": alice})


# ROOT CHAIN DAO


@pytest.fixture(scope="module")
def curve_dao(pm):
    return pm("curvefi/curve-dao-contracts@1.3.0")


@pytest.fixture(scope="module")
def root_crv_token(alice, chain, curve_dao):
    crv = curve_dao.ERC20CRV.deploy("Root Curve DAO Token", "rCRV", 18, {"from": alice})
    chain.sleep(86400 * 14)
    crv.update_mining_parameters({"from": alice})
    return crv


@pytest.fixture(scope="module")
def root_voting_escrow(alice, root_crv_token, curve_dao):
    return curve_dao.VotingEscrow.deploy(
        root_crv_token, "Dummy VECRV", "veCRV", "v1", {"from": alice}
    )


@pytest.fixture(scope="module")
def root_gauge_controller(alice, root_crv_token, root_voting_escrow, curve_dao):
    return curve_dao.GaugeController.deploy(root_crv_token, root_voting_escrow, {"from": alice})


@pytest.fixture(scope="module")
def root_minter(alice, root_crv_token, root_gauge_controller, curve_dao):
    minter = curve_dao.Minter.deploy(root_crv_token, root_gauge_controller, {"from": alice})
    root_crv_token.set_minter(minter, {"from": alice})
    return minter


# ROOT CHAIN DEPLOYMENTS


@pytest.fixture(scope="module")
def root_gauge_factory(alice, anycall, chain, RootGaugeFactory):
    factory = RootGaugeFactory.deploy(anycall, alice, {"from": alice})
    anycall.setWhitelist(factory, factory, chain.id, True, {"from": alice})
    return factory


@pytest.fixture(scope="module")
def mock_bridger(alice, chain, root_gauge_factory, MockBridger):
    bridger = MockBridger.deploy({"from": alice})
    root_gauge_factory.set_bridger(chain.id, bridger, {"from": alice})
    return bridger


@pytest.fixture(scope="module")
def root_gauge_impl(
    alice,
    root_gauge_controller,
    root_minter,
    root_crv_token,
    root_gauge_factory,
    mock_bridger,
    RootGauge,
):
    impl = RootGauge.deploy(root_crv_token, root_gauge_controller, root_minter, {"from": alice})
    root_gauge_factory.set_implementation(impl, {"from": alice})
    return impl


@pytest.fixture(scope="module")
def root_gauge(alice, chain, root_gauge_factory, root_gauge_impl, RootGauge):
    gauge_addr = root_gauge_factory.deploy_gauge(chain.id, 0x0, {"from": alice}).return_value
    return Contract.from_abi("Root Gauge", gauge_addr, RootGauge.abi)


@pytest.fixture(scope="module")
def root_oracle(alice, anycall, chain, root_gauge_factory, root_voting_escrow, RootOracle):
    oracle = RootOracle.deploy(root_gauge_factory, root_voting_escrow, anycall, {"from": alice})
    anycall.setWhitelist(oracle, oracle, chain.id, True, {"from": alice})
    return oracle
