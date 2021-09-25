import pytest
from brownie import ETH_ADDRESS
from eth_abi.abi import encode_single


@pytest.fixture(scope="module", autouse=True)
def setup(alice, child_factory, mock_child_gauge_implementation):
    child_factory.set_implementation(mock_child_gauge_implementation, {"from": alice})


def test_deploy_gauge(
    alice,
    chain,
    child_factory,
    mock_child_gauge_implementation,
    create2_address_of,
    keccak,
    vyper_proxy_init_code,
):
    salt = keccak(encode_single("(uint256,address,uint256)", [chain.id, alice.address, 0]))
    expected_proxy_address = create2_address_of(
        child_factory.address, salt, vyper_proxy_init_code(mock_child_gauge_implementation.address)
    )

    tx = child_factory.deploy_gauge(ETH_ADDRESS, {"from": alice})

    assert tx.new_contracts[0] == expected_proxy_address
    assert "GaugeDeployed" in tx.events
    assert tx.events["GaugeDeployed"] == dict(
        _deployer=alice, _gauge=expected_proxy_address, _receiver=ETH_ADDRESS
    )


def test_initialize_subcall(alice, child_factory, mock_child_gauge_implementation):
    tx = child_factory.deploy_gauge(ETH_ADDRESS, {"from": alice})

    assert tx.subcalls[-2] == {
        "calldata": mock_child_gauge_implementation.initialize.encode_input(alice, ETH_ADDRESS),
        "from": child_factory,
        "op": "CALL",
        "to": tx.new_contracts[0],
        "value": 0,
    }


def test_nonce_increments(alice, child_factory):
    pre_nonce = child_factory.nonces(alice)
    child_factory.deploy_gauge(ETH_ADDRESS, {"from": alice})

    assert child_factory.nonces(alice) == pre_nonce + 1


def test_gauge_list_updates(alice, child_factory):
    tx = child_factory.deploy_gauge(ETH_ADDRESS, {"from": alice})

    assert child_factory.get_size() == 1
    assert child_factory.get_gauge(0) == tx.new_contracts[0]
