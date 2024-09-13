from brownie import Contract, web3
from eth_abi import encode

SALT = b"5A170000000000000000000000000000"


def test_gauge_address(
    alice,
    chain,
    root_gauge_factory,
    child_gauge_factory,
    lp_token,
    child_gauge_impl,
    RootGauge,
    ChildGauge,
    vyper_proxy_init_code,
    create2_address_of,
):
    child = Contract.from_abi(
        "Child", child_gauge_factory.deploy_gauge(lp_token, SALT).return_value, abi=ChildGauge.abi
    )
    root = Contract.from_abi(
        "Root",
        root_gauge_factory.deploy_gauge(chain.id, SALT, {"from": alice}).return_value,
        abi=RootGauge.abi,
    )

    assert child.root_gauge() == root, "Bad root gauge calculation"
    assert root.child_gauge() == child, "Bad child gauge calculation"


def test_gauge_address_chain_id(
    alice,
    chain,
    root_gauge_factory,
    child_gauge_factory,
    lp_token,
    child_gauge_impl,
    MockBridger,
    RootGauge,
    vyper_proxy_init_code,
    create2_address_of,
):
    chain_id = chain.id + 1
    proxy_init_code = vyper_proxy_init_code(child_gauge_impl.address)
    expected = create2_address_of(
        child_gauge_factory.address, web3.keccak(encode(["(uint256,bytes32)"], [(chain_id, SALT)])), proxy_init_code
    )
    bridger = MockBridger.deploy({"from": alice})
    root_gauge_factory.set_child(
        chain_id, bridger, child_gauge_factory, child_gauge_impl, {"from": alice}
    )
    root = Contract.from_abi(
        "Root",
        root_gauge_factory.deploy_gauge(chain.id + 1, SALT, {"from": alice}).return_value,
        abi=RootGauge.abi,
    )

    assert root.child_gauge() == expected, "Bad child gauge calculation"
