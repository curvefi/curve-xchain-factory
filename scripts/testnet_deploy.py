import brownie
from brownie import (
    ChildLiquidityGauge,
    ChildLiquidityGaugeFactory,
    ChildManager,
    Minter,
    RootLiquidityGauge,
    RootLiquidityGaugeFactory,
    RootManager,
    accounts,
    compile_source,
)
from brownie._config import _get_data_folder
from brownie_tokens import ERC20

path = _get_data_folder().joinpath("packages/curvefi/curve-dao-contracts@1.3.0")
CurveDAOProject = brownie.project.load(path, "CurveDAOProject")

DEPLOYER_1 = accounts.load("dev")
DEPLOYER_2 = accounts.load("proxy")
ANYCALL = "0xd50aB2485E20103fbd0a7E8C09230bFbef6D4e90"


def deploy_root():
    src = CurveDAOProject.ERC20CRV._build["source"].replace(
        "INFLATION_DELAY: constant(uint256) = 86400", "INFLATION_DELAY: constant(uint256) = 0", 1
    )

    # deploy DAO infrastructure first
    token = compile_source(src, vyper_version="0.2.4").Vyper.deploy(
        "mock CRV", "mCRV", 18, {"from": DEPLOYER_1}
    )
    voting = CurveDAOProject.VotingEscrow.deploy(
        token, "mock veCRV", "mveCRV", "v1", {"from": DEPLOYER_1}
    )
    gauge_controller = CurveDAOProject.GaugeController.deploy(token, voting, {"from": DEPLOYER_1})
    minter = CurveDAOProject.Minter.deploy(token, gauge_controller, {"from": DEPLOYER_1})
    token.set_minter(minter, {"from": DEPLOYER_1})

    # dummy tx
    DEPLOYER_2.transfer(DEPLOYER_2, 0)
    # factory
    root_factory = RootLiquidityGaugeFactory.deploy(DEPLOYER_2, {"from": DEPLOYER_2})
    # dummy tx
    DEPLOYER_2.transfer(DEPLOYER_2, 0)
    # manager
    RootManager.deploy(ANYCALL, root_factory, voting, {"from": DEPLOYER_2})
    # gauge implementation
    gauge = RootLiquidityGauge.deploy(token, gauge_controller, minter, {"from": DEPLOYER_2})
    root_factory.set_implementation(gauge, {"from": DEPLOYER_2})


def deploy_child():
    # deploy coin
    token = ERC20("Dummy Token", "dmmy", 18, deployer=DEPLOYER_2)
    # factory
    child_factory = ChildLiquidityGaugeFactory.deploy(DEPLOYER_2, {"from": DEPLOYER_2})
    # minter
    child_minter = Minter.deploy(ANYCALL, token, child_factory, {"from": DEPLOYER_2})
    # manager
    child_manager = ChildManager.deploy(ANYCALL, child_factory, child_minter, {"from": DEPLOYER_2})
    # gauge implementation
    gauge = ChildLiquidityGauge.deploy(token, child_minter, {"from": DEPLOYER_2})
    child_factory.set_implementation(gauge, {"from": DEPLOYER_2})
    child_minter.set_manager(child_manager, {"from": DEPLOYER_2})
