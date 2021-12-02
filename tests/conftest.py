import pytest

pytest_plugins = ["fixtures.accounts", "fixtures.deployments", "fixtures.functions"]


def pytest_sessionfinish(session, exitstatus):
    if exitstatus == pytest.ExitCode.NO_TESTS_COLLECTED:
        # we treat "no tests collected" as passing
        session.exitstatus = pytest.ExitCode.OK


@pytest.fixture(scope="session")
def curve_dao(pm):
    return pm("curvefi/curve-dao-contracts@1.3.0")


@pytest.fixture(scope="module", autouse=True)
def mod_isolation(chain):
    chain.snapshot()
    yield
    chain.revert()


@pytest.fixture(autouse=True)
def isolation(chain, history):
    start = len(history)
    yield
    end = len(history)
    if end - start > 0:
        chain.undo(end - start)
