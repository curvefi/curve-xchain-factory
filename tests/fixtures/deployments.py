import pytest
from brownie import Contract
from brownie_tokens import ERC20

# ANYCALL DEPLOYMENT


@pytest.fixture(scope="session")
def anycall(alice, AnyCallProxy):
    instance = AnyCallProxy.deploy(alice, {"from": alice})
    # disable whitelist for simplicity
    # live deployment requires each `to` address to be
    # whitelisted on both ends (root/child chain)
    instance.disableWhitelist({"from": alice})
    return instance


# CHILD CHAIN DEPLOYMENTS


@pytest.fixture(scope="session")
def child_gauge_factory(alice, anycall, ChildLiquidityGaugeFactory):
    return ChildLiquidityGaugeFactory.deploy(alice, {"from": alice})


@pytest.fixture(scope="session")
def child_crv_token(alice):
    return ERC20("Child Curve DAO Token", "cCRV", 18, deployer=alice)


@pytest.fixture(scope="session")
def child_minter(alice, anycall, child_gauge_factory, child_crv_token, Minter):
    return Minter.deploy(anycall, child_crv_token, child_gauge_factory, {"from": alice})


@pytest.fixture(scope="session")
def lp_token(alice):
    return ERC20("Dummy LP Token", "dLP", 18, deployer=alice)


@pytest.fixture(scope="session")
def reward_token(alice):
    return ERC20("Dummy Reward Token", "dRT", 18, deployer=alice)


@pytest.fixture(scope="module")
def child_gauge_impl(
    alice, child_crv_token, child_minter, ChildLiquidityGauge, child_gauge_factory
):
    impl = ChildLiquidityGauge.deploy(child_crv_token, child_minter, {"from": alice})
    child_gauge_factory.set_implementation(impl, {"from": alice})
    return impl


@pytest.fixture(scope="module")
def child_gauge(alice, child_gauge_impl, child_gauge_factory, lp_token, ChildLiquidityGauge):
    gauge_addr = child_gauge_factory.deploy_gauge(lp_token, 0x0, {"from": alice}).return_value
    return Contract.from_abi("Child Gauge", gauge_addr, ChildLiquidityGauge.abi)


# ROOT CHAIN DAO


@pytest.fixture(scope="session")
def curve_dao(pm):
    return pm("curvefi/curve-dao-contracts@1.3.0")


@pytest.fixture(scope="session")
def root_crv_token(alice, chain, curve_dao):
    crv = curve_dao.ERC20CRV.deploy("Root Curve DAO Token", "rCRV", 18, {"from": alice})
    chain.sleep(86400 * 14)
    crv.update_mining_parameters({"from": alice})
    return crv


@pytest.fixture(scope="session")
def root_voting_escrow(alice, root_crv_token, curve_dao):
    return curve_dao.VotingEscrow.deploy(
        root_crv_token, "Dummy VECRV", "veCRV", "v1", {"from": alice}
    )


@pytest.fixture(scope="session")
def root_gauge_controller(alice, root_crv_token, root_voting_escrow, curve_dao):
    return curve_dao.GaugeController.deploy(root_crv_token, root_voting_escrow, {"from": alice})


@pytest.fixture(scope="session")
def root_minter(alice, root_crv_token, root_gauge_controller, curve_dao):
    minter = curve_dao.Minter.deploy(root_crv_token, root_gauge_controller, {"from": alice})
    root_crv_token.set_minter(minter, {"from": alice})
    return minter


# ROOT CHAIN DEPLOYMENTS


@pytest.fixture(scope="session")
def root_gauge_factory(alice, RootLiquidityGaugeFactory):
    return RootLiquidityGaugeFactory.deploy(alice, {"from": alice})


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
    RootLiquidityGauge,
):
    impl = RootLiquidityGauge.deploy(
        root_crv_token, root_gauge_controller, root_minter, {"from": alice}
    )
    root_gauge_factory.set_implementation(impl, {"from": alice})
    return impl


@pytest.fixture(scope="module")
def root_gauge(alice, chain, root_gauge_factory, root_gauge_impl, RootLiquidityGauge):
    gauge_addr = root_gauge_factory.deploy_gauge(chain.id, 0x0, {"from": alice}).return_value
    return Contract.from_abi("Root Gauge", gauge_addr, RootLiquidityGauge.abi)
