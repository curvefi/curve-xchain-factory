import brownie


def test_deploy_gauge_successful(
    alice, anycall, child_gauge_factory, lp_token, child_manager, child_minter
):
    tx = child_manager.deploy_gauge(lp_token, 0x0, alice, {"from": anycall})

    assert child_minter.has_counterpart(tx.return_value[-1]) is True
    assert child_gauge_factory.is_valid_gauge(tx.return_value[-1]) is True


def test_deploy_gauge_unsuccessful(alice, lp_token, child_manager):
    with brownie.reverts():
        child_manager.deploy_gauge(lp_token, 0x0, alice, {"from": alice})


def test_receive_ve_data_successful(alice, chain, anycall, child_manager):
    tx = child_manager.receive_ve_data(
        alice,
        100 * 10 ** 18,
        chain.time() + 86400 * 365 * 4,
        100 * 10 ** 18,
        chain.time(),
        {"from": anycall},
    )

    assert "UpdateVEBalance" in tx.events
    assert "UpdateVETotalSupply" in tx.events

    assert child_manager.totalSupply() <= 100 * 10 ** 18
    assert child_manager.balanceOf(alice) <= 100 * 10 ** 18
    assert child_manager.locked__end(alice) >= tx.timestamp + 86400 * 365 * 4


def test_receive_ve_data_unsuccessful(alice, chain, child_manager):
    with brownie.reverts():
        child_manager.receive_ve_data(
            alice,
            100 * 10 ** 18,
            chain.time() + 86400 * 365 * 4,
            100 * 10 ** 18,
            chain.time(),
            {"from": alice},
        )
