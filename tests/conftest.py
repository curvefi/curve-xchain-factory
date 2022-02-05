import pytest

pytest_plugins = ["fixtures.accounts", "fixtures.deployments", "fixtures.functions"]


def pytest_sessionfinish(session, exitstatus):
    if exitstatus == pytest.ExitCode.NO_TESTS_COLLECTED:
        # we treat "no tests collected" as passing
        session.exitstatus = pytest.ExitCode.OK


@pytest.fixture(scope="session")
def curve_dao(pm):
    return pm("curvefi/curve-dao-contracts@1.3.0")


@pytest.fixture(autouse=True)
def isolation(module_isolation, fn_isolation):
    pass
