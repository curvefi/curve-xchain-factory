import pytest
from eth_abi.abi import encode_single


@pytest.fixture(scope="module", autouse=True)
def setup(alice, chain, root_factory, mock_root_gauge_implementation):
    root_factory.set_implementation(chain.id, mock_root_gauge_implementation, {"from": alice})


def test_deploy_gauge(
    alice,
    chain,
    root_factory,
    mock_root_gauge_implementation,
    create2_address_of,
    keccak,
    vyper_proxy_init_code,
):
    salt = keccak(encode_single("(uint256,address,uint256)", [chain.id, alice.address, 0]))
    expected_proxy_address = create2_address_of(
        root_factory.address, salt, vyper_proxy_init_code(mock_root_gauge_implementation.address)
    )

    tx = root_factory.deploy_gauge(chain.id, {"from": alice})

    assert tx.new_contracts[0] == expected_proxy_address
    assert "GaugeDeployed" in tx.events
    assert tx.events["GaugeDeployed"] == dict(
        _chain_id=chain.id, _deployer=alice, _gauge=expected_proxy_address
    )


def test_initialize_subcall(alice, chain, root_factory, mock_root_gauge_implementation):
    tx = root_factory.deploy_gauge(chain.id, {"from": alice})

    assert tx.subcalls[-2] == {
        "calldata": mock_root_gauge_implementation.initialize.encode_input(chain.id, alice),
        "from": root_factory,
        "op": "CALL",
        "to": tx.new_contracts[0],
        "value": 0,
    }


def test_nonce_increments(alice, chain, root_factory):
    pre_nonce = root_factory.nonces(chain.id, alice)
    root_factory.deploy_gauge(chain.id, {"from": alice})

    assert root_factory.nonces(chain.id, alice) == pre_nonce + 1


def test_gauge_list_updates(alice, chain, root_factory):
    tx = root_factory.deploy_gauge(chain.id, {"from": alice})

    assert root_factory.get_size(chain.id) == 1
    assert root_factory.get_gauge(chain.id, 0) == tx.new_contracts[0]
