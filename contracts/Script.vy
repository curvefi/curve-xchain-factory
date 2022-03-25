# @version 0.3.1


interface AnyCall:
    def deposit(_account: address): payable

interface Factory:
    def deploy_child_gauge(
        _chain_id: uint256, _lp_token: address, _salt: bytes32, _manager: address
    ): nonpayable


struct GaugeParams:
    chain_id: uint256
    lp_token: address
    salt: bytes32
    manager: address
    predicted_address: address


ANYCALL: constant(address) = 0x37414a8662bC1D25be3ee51Fb27C2686e2490A89
FACTORY: constant(address) = 0xabC000d88f23Bb45525E447528DBF656A9D55bf5

ARBITRUM_CHAIN_ID: constant(uint256) = 42161
N_GAUGES: constant(uint256) = 17


@external
def __init__(_params: GaugeParams[N_GAUGES]):
    """
    @dev Requires 4 ETH to be sent along in the transaction
    """
    for i in range(N_GAUGES):
        # initiate the deployment process
        Factory(FACTORY).deploy_child_gauge(
            _params[i].chain_id, _params[i].lp_token, _params[i].salt, _params[i].manager
        )

        # arbitrum requires some ETH to bridge CRV
        if _params[i].chain_id == ARBITRUM_CHAIN_ID:
            # send eth to pay for future bridging fees to expected gauge address
            send(_params[i].predicted_address, as_wei_value(0.5, "ether"))  # 4 gauges = 2 ETH

    # increase execution budget for future callbacks used in deployment process
    AnyCall(ANYCALL).deposit(FACTORY, value=as_wei_value(2, "ether"))
    selfdestruct(msg.sender)
