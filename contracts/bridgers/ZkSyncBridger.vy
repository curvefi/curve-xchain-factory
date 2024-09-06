# pragma version 0.4.0
"""
@title Curve zkSync BridgeHub Wrapper
@author CurveFi
@license MIT
@custom:version 0.0.1
"""

version: public(constant(String[8])) = "0.0.1"


from ethereum.ercs import IERC20
from snekmate.auth import ownable

initializes: ownable


interface ZkSyncBridgeHub:
    def requestL2TransactionTwoBridges(request: L2TransactionRequestTwoBridgesOuter) -> bytes32: payable
    def sharedBridge() -> address: view
    def baseToken(_chainId: uint256) -> IERC20: view


event DestinationDataUpdate:
    chain_id: indexed(uint256)
    destination_data: DestinationData


struct L2TransactionRequestTwoBridgesOuter:
    chainId: uint256
    mintValue: uint256
    l2Value: uint256
    l2GasLimit: uint256
    l2GasPerPubdataByteLimit: uint256
    refundRecipient: address
    secondBridgeAddress: address
    secondBridgeValue: uint256
    secondBridgeCalldata: Bytes[MAX_TRANSFER_LEN]

struct DestinationData:
    bridge: address  # Shared Bridge
    base_token: IERC20
    l2_gas_limit: uint256
    l2_gas_price_limit: uint256  # (Default) Gas per Pubdata Byte Limit
    refund_recipient: address  # FeeCollector or Curve Vault
    allow_custom_refund: bool

struct ManualParameters:
    l2GasPerPubdataByteLimit: uint256
    refund_recipient: address  # if allowed
    gas_value: uint256  # amount in case of baseToken != ETH

struct RecoverInput:
    coin: IERC20
    amount: uint256


ZK_SYNC_ETH_ADDRESS: constant(address) = 0x0000000000000000000000000000000000000001
MAX_TRANSFER_LEN: constant(uint256) = 3 * 32

BRIDGE_HUB: public(immutable(ZkSyncBridgeHub))
# chain id -> DestinationData (default at chain_id=0)
destination_data: public(HashMap[uint256, DestinationData])

owner: public(address)

manual_parameters: transient(ManualParameters)


@deploy
def __init__(_bridge_hub: address):
    BRIDGE_HUB = ZkSyncBridgeHub(_bridge_hub)
    crv: IERC20 = IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52)
    assert extcall crv.approve(_bridge_hub, max_value(uint256))

    default_data: DestinationData = DestinationData(
        bridge=staticcall BRIDGE_HUB.sharedBridge(),
        base_token=empty(IERC20),
        l2_gas_limit=2 * 10 ** 6,  # Create token if necessary + transfers
        l2_gas_price_limit=800,
        refund_recipient=empty(address),
        allow_custom_refund=True,
    )
    self.destination_data[0] = default_data
    log DestinationDataUpdate(0, default_data)

    ownable.__init__()


exports: ownable.transfer_ownership


@internal
def _receive_token(token: IERC20, amount: uint256) -> uint256:
    if amount == max_value(uint256):
        amount = min(staticcall token.balanceOf(msg.sender), staticcall token.allowance(msg.sender, self))
    assert extcall token.transferFrom(msg.sender, self, amount, default_return_value=True)

    return staticcall token.balanceOf(self)


@internal
def _fetch_destination_data(chain_id: uint256) -> DestinationData:
    """
    @notice Try fetching default parameters if nothing set
    """
    data: DestinationData = self.destination_data[chain_id]
    if data.bridge == empty(address):
        data = self.destination_data[0]  # default
        data.base_token = staticcall BRIDGE_HUB.baseToken(chain_id)
        assert data.base_token != empty(IERC20), "baseToken not set"

        self.destination_data[chain_id] = data  # Update for future uses
        log DestinationDataUpdate(chain_id, data)
    return data


@internal
def _applied_destination_data(chain_id: uint256) -> (DestinationData, uint256):
    """
    @notice Fetch destination data and apply manual parameters
    """
    data: DestinationData = self._fetch_destination_data(chain_id)

    l2_gas_price_limit: uint256 = self.manual_parameters.l2GasPerPubdataByteLimit
    if l2_gas_price_limit > 0:
        data.l2_gas_price_limit = l2_gas_price_limit

    if data.allow_custom_refund:
        refund_recipient: address = self.manual_parameters.refund_recipient
        if refund_recipient != empty(address):
            data.refund_recipient = refund_recipient

    gas_value: uint256 = self.balance
    if data.base_token.address != ZK_SYNC_ETH_ADDRESS:
        gas_value = self.manual_parameters.gas_value
        assert extcall data.base_token.transferFrom(msg.sender, self, gas_value, default_return_value=True)
        if staticcall data.base_token.allowance(self, data.bridge) < gas_value:
            extcall data.base_token.approve(data.bridge, max_value(uint256))

    return data, gas_value


@external
@payable
def bridge(_chain_id: uint256, _token: IERC20, _to: address, _amount: uint256, _min_amount: uint256=0) -> uint256:
    """
    @notice Bridge a token to zkSync using BridgedHub with SharedBridge.
        Might need manual parameters change from bridge initiator.
    @param _chain_id Chain ID of L2 (e.g. 324)
    @param _token The token to bridge (base token is not supported)
    @param _to The address to deposit the token to on L2
    @param _amount The amount of the token to deposit, 2^256-1 for the whole available balance
    @param _min_amount Minimum amount when to bridge
    @return Bridged amount
    """
    amount: uint256 = self._receive_token(_token, _amount)
    assert amount >= _min_amount, "Amount too small"

    data: DestinationData = empty(DestinationData)
    gas_value: uint256 = 0
    data, gas_value = self._applied_destination_data(_chain_id)

    if staticcall _token.allowance(self, data.bridge) < amount:
        extcall _token.approve(data.bridge, max_value(uint256))

    extcall BRIDGE_HUB.requestL2TransactionTwoBridges(
        L2TransactionRequestTwoBridgesOuter(
            chainId=_chain_id,
            mintValue=gas_value,
            l2Value=0,
            l2GasLimit=data.l2_gas_limit,
            l2GasPerPubdataByteLimit=data.l2_gas_price_limit,
            refundRecipient=data.refund_recipient,
            secondBridgeAddress=data.bridge,
            secondBridgeValue=0,
            secondBridgeCalldata=abi_encode(_token.address, amount, _to),
        ),
        value=gas_value if data.base_token.address == ZK_SYNC_ETH_ADDRESS else 0,
    )
    return amount


@view
@external
def check(_account: address) -> bool:
    """
    @notice Dummy method to check if caller is allowed to bridge
    @param _account The account to check
    """
    return True


@view
@external
def cost(_chain_id: uint256) -> uint256:
    """
    @notice Cost in ETH to bridge. Not supported
    """
    return 0


@external
def set_manual_parameters(_manual_parameters: ManualParameters):
    """
    @notice Set manual parameters that will be actual within current transaction
    """
    self.manual_parameters = _manual_parameters


@external
def set_destination_data(_chain_id: uint256, _destination_data: DestinationData):
    """
    @notice Set custom destination data. In order to turn off chain id set bridge=0xdead
    """
    ownable._check_owner()

    self.destination_data[_chain_id] = _destination_data
    log DestinationDataUpdate(_chain_id, _destination_data)


@external
def recover(_recovers: DynArray[RecoverInput, 64], _receiver: address):
    """
    @notice Recover ERC20 tokens or Ether from this contract
    @dev Callable only by owner and emergency owner
    @param _recovers (Token, amount) to recover
    @param _receiver Receiver of coins
    """
    ownable._check_owner()

    for input: RecoverInput in _recovers:
        amount: uint256 = input.amount
        if input.coin.address == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE:
            if amount == max_value(uint256):
                amount = self.balance
            raw_call(_receiver, b"", value=amount)
        else:
            if amount == max_value(uint256):
                amount = staticcall input.coin.balanceOf(self)
            extcall input.coin.transfer(_receiver, amount, default_return_value=True)  # do not need safe transfer
