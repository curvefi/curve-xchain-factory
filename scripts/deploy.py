from brownie import (
    ZERO_ADDRESS,
    ChildGauge,
    ChildGaugeFactory,
    RootGauge,
    RootGaugeFactory,
    RootGaugeFactoryProxy,
    accounts,
)

DEPLOYER = accounts.load("xchain_deployer", password="Xorg")
txparams = {"from": DEPLOYER, "priority_fee": "1 gwei", "max_fee": "20 gwei"}

CRV = "0xD533a949740bb3306d119CC777fa900bA034cd52"
GAUGE_CONTROLLER = "0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB"
MINTER = "0xd061D61a4d941c39E5453435B6345Dc261C2fcE0"
VE = "0x5f3b5DfEb7B28CDbD7FAba78963EE202a494e2A2"

ANYCALL = ZERO_ADDRESS

L2_CRV20 = ""
# txparams = {"from": DEPLOYER}  # , "gas_price": "150 gwei"}


def deploy_root():
    factory = RootGaugeFactory.deploy(ANYCALL, DEPLOYER, txparams)
    gauge_impl = RootGauge.deploy(CRV, GAUGE_CONTROLLER, MINTER, txparams)

    # set implementation
    factory.set_implementation(gauge_impl, txparams)

    # bridger = OptimismBridger.deploy(L2_CRV20, L1_BRIDGE, txparams)
    # factory.set_child(5000, bridger, ...txparams)

    proxy = RootGaugeFactoryProxy.deploy(txparams)
    factory.commit_transfer_ownership(proxy, txparams)
    proxy.accept_transfer_ownership(factory, txparams)


def deploy_child(crv_addr=L2_CRV20):
    factory = ChildGaugeFactory.deploy(ANYCALL, crv_addr, DEPLOYER, txparams)
    gauge_impl = ChildGauge.deploy(crv_addr, factory, txparams)

    # set implementation
    factory.set_implementation(gauge_impl, txparams)
