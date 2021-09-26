import pytest
from brownie import ETH_ADDRESS, Contract

WEEK = 86400 * 7


@pytest.fixture(scope="module")
def anyswap_root_gauge(alice, chain, root_factory, anyswap_root_gauge_implementation):
    root_factory.set_implementation(chain.id, anyswap_root_gauge_implementation, {"from": alice})
    tx = root_factory.deploy_gauge(chain.id, {"from": alice})

    return Contract.from_abi(
        "Anyswap Root Gauge Instance", tx.return_value, anyswap_root_gauge_implementation.abi
    )


def test_anyswap_root_gauge_transfer_crv(alice, chain, gauge_controller, anyswap_root_gauge, token):
    gauge_controller.add_type("Test", 10 ** 18, {"from": alice})
    gauge_controller.add_gauge(anyswap_root_gauge, 0, 1, {"from": alice})

    chain.mine(timedelta=2 * WEEK)

    amount = token.rate() * WEEK

    tx = anyswap_root_gauge.checkpoint({"from": alice})

    transfer_subcall = tx.subcalls[-1]

    assert transfer_subcall["function"] == "transfer(address,uint256)"
    assert transfer_subcall["to"] == token
    assert list(transfer_subcall["inputs"].values()) == [ETH_ADDRESS, amount]

    assert token.balanceOf(ETH_ADDRESS) == amount
