import pytest
from brownie_tokens import ERC20

# CHILD CHAIN DEPLOYMENTS


@pytest.fixture(scope="session")
def child_gauge_factory(alice, ChildLiquidityGaugeFactory):
    return ChildLiquidityGaugeFactory.deploy(alice, {"from": alice})


@pytest.fixture(scope="session")
def child_crv_token(alice):
    return ERC20("Child Curve DAO Token", "cCRV", 18, deployer=alice)


@pytest.fixture(scope="session")
def child_minter(alice, child_gauge_factory, child_crv_token, Minter):
    return Minter.deploy(child_gauge_factory, child_crv_token, {"from": alice})


@pytest.fixture(scope="session")
def child_gauge_impl(
    alice, child_crv_token, child_minter, ChildLiquidityGauge, child_gauge_factory
):
    impl = ChildLiquidityGauge.deploy(child_crv_token, child_minter, {"from": alice})
    child_gauge_factory.set_implementation(impl, {"from": alice})
    return impl


@pytest.fixture(scope="session")
def lp_token(alice):
    return ERC20("Dummy LP Token", "dLP", 18, deployer=alice)
