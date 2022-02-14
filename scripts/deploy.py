from brownie import (
    ChildGauge,
    ChildGaugeFactory,
    ChildOracle,
    RootGauge,
    RootGaugeFactory,
    RootOracle,
    accounts,
)

DEPLOYER = accounts.load("xchain-deployer")

CRV = "0xD533a949740bb3306d119CC777fa900bA034cd52"
GAUGE_CONTROLLER = "0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB"
MINTER = "0xd061D61a4d941c39E5453435B6345Dc261C2fcE0"
VE = "0x5f3b5DfEb7B28CDbD7FAba78963EE202a494e2A2"

ANYCALL = "0x37414a8662bc1d25be3ee51fb27c2686e2490a89"


def deploy_root():
    factory = RootGaugeFactory.deploy(ANYCALL, DEPLOYER, {"from": DEPLOYER})
    gauge_impl = RootGauge.deploy(CRV, GAUGE_CONTROLLER, MINTER, {"from": DEPLOYER})
    RootOracle.deploy(factory, VE, ANYCALL, {"from": DEPLOYER})

    # set implementation
    factory.set_implementation(gauge_impl, {"from": DEPLOYER})


def deploy_child(crv_addr):
    factory = ChildGaugeFactory.deploy(ANYCALL, crv_addr, DEPLOYER, {"from": DEPLOYER})
    gauge_impl = ChildGauge.deploy(crv_addr, factory, {"from": DEPLOYER})
    ChildOracle.deploy(ANYCALL, {"from": DEPLOYER})

    # set implementation
    factory.set_implementation(gauge_impl, {"from": DEPLOYER})
