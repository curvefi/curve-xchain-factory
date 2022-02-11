def test_deploy_gauge_successful(alice, anycall, child_gauge_factory, lp_token):
    tx = child_gauge_factory.deploy_gauge(lp_token, 0x0, alice, {"from": anycall})

    assert child_gauge_factory.is_mirrored(tx.return_value) is True
    assert child_gauge_factory.is_valid_gauge(tx.return_value) is True
