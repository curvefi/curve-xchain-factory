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
