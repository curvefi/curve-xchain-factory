# @version 0.3.1
"""
@title Token Minter
@author Curve Finance
@license MIT
"""


interface AnyCall:
    def encode(_sig: String[128], _data: Bytes[256]) -> ByteArray: pure

interface LiquidityGauge:
    # Presumably, other gauges will provide the same interfaces
    def integrate_fraction(addr: address) -> uint256: view
    def user_checkpoint(addr: address) -> bool: nonpayable

interface Factory:
    def is_valid_gauge(_gauge: address) -> bool: view


event Minted:
    recipient: indexed(address)
    gauge: address
    minted: uint256

event TransferOwnership:
    _old_owner: address
    _new_owner: address


struct ByteArray:
    position: uint256
    length: uint256
    data: uint256[2]


WEEK: constant(uint256) = 86400 * 7

ANYCALL: immutable(address)
TOKEN: immutable(address)
FACTORY: immutable(address)


# user -> gauge -> value
minted: public(HashMap[address, HashMap[address, uint256]])

# minter -> user -> can mint?
allowed_to_mint_for: public(HashMap[address, HashMap[address, bool]])

# [last_request][has_counterpart]
gauge_data: HashMap[address, uint256]

owner: public(address)
future_owner: public(address)
manager: public(address)


@external
def __init__(_anycall: address, _token: address, _factory: address):
    ANYCALL = _anycall
    TOKEN = _token
    FACTORY = _factory

    self.owner = msg.sender
    self.manager = msg.sender

    log TransferOwnership(ZERO_ADDRESS, msg.sender)


@internal
def _mint_for(gauge_addr: address, _for: address):
    assert Factory(FACTORY).is_valid_gauge(gauge_addr)  # dev: invalid gauge

    gauge_data: uint256 = self.gauge_data[gauge_addr]
    # if has root counterpart & request was made before this week
    if shift(gauge_data, -128) == 1 and gauge_data % 2 ** 128 / WEEK < block.timestamp / WEEK:

        # cost is negligible on sidechains no need to hand roll abi.encodePacked
        data: uint256[2] = AnyCall(ANYCALL).encode(
            "transmit_emissions(address)", _abi_encode(gauge_addr)
        ).data

        # send the request cross-chain
        raw_call(
            ANYCALL,
            _abi_encode(
                convert(160, uint256),  # address[] - 0
                convert(224, uint256),  # bytes[] - 1
                convert(384, uint256),  # address[] - 2
                convert(416, uint256),  # uint256[] - 3
                convert(1, uint256),  # uint256 - 4
                convert(1, uint256),  # number of address elements - 5
                FACTORY,  # 6
                convert(1, uint256),  # number of bytes elements - 7
                convert(32, uint256),  # bytes start pos - 8
                convert(36, uint256),  # length in bytes - 9
                data,  # bytes right padded - 10/11
                convert(0, uint256),  # number of address elements - 12
                convert(0, uint256),  # number of uint256 elements - 13
                method_id=method_id("anyCall(address[],bytes[],address[],uint256[],uint256)"),
            )
        )
        self.gauge_data[gauge_addr] = shift(1, 128) + block.timestamp

    LiquidityGauge(gauge_addr).user_checkpoint(_for)
    total_mint: uint256 = LiquidityGauge(gauge_addr).integrate_fraction(_for)
    to_mint: uint256 = total_mint - self.minted[_for][gauge_addr]

    if to_mint != 0:
        resp: Bytes[32] = raw_call(
            TOKEN,
            _abi_encode(
                _for,
                to_mint,
                method_id=method_id("transfer(address,uint256)"),
            ),
            max_outsize=32
        )
        if len(resp) != 0:
            assert convert(resp, bool)
        self.minted[_for][gauge_addr] = total_mint

        log Minted(_for, gauge_addr, total_mint)


@external
@nonreentrant('lock')
def mint(gauge_addr: address):
    """
    @notice Mint everything which belongs to `msg.sender` and send to them
    @param gauge_addr `LiquidityGauge` address to get mintable amount from
    """
    self._mint_for(gauge_addr, msg.sender)


@external
@nonreentrant('lock')
def mint_many(gauge_addrs: address[8]):
    """
    @notice Mint everything which belongs to `msg.sender` across multiple gauges
    @param gauge_addrs List of `LiquidityGauge` addresses
    """
    for i in range(8):
        if gauge_addrs[i] == ZERO_ADDRESS:
            break
        self._mint_for(gauge_addrs[i], msg.sender)


@external
@nonreentrant('lock')
def mint_for(gauge_addr: address, _for: address):
    """
    @notice Mint tokens for `_for`
    @dev Only possible when `msg.sender` has been approved via `toggle_approve_mint`
    @param gauge_addr `LiquidityGauge` address to get mintable amount from
    @param _for Address to mint to
    """
    if self.allowed_to_mint_for[msg.sender][_for]:
        self._mint_for(gauge_addr, _for)


@external
def toggle_approve_mint(minting_user: address):
    """
    @notice allow `minting_user` to mint for `msg.sender`
    @param minting_user Address to toggle permission for
    """
    self.allowed_to_mint_for[minting_user][msg.sender] = not self.allowed_to_mint_for[minting_user][msg.sender]


@external
def set_has_counterpart(_gauge: address, _has_counterpart: bool):
    """
    @notice Set boolean denoting a gauge has a root counterpart
    """
    assert msg.sender == self.manager or msg.sender == self.owner

    self.gauge_data[_gauge] = shift(convert(_has_counterpart, uint256), 128) + self.gauge_data[_gauge] % 2 ** 128


@external
def set_manager(_new_manager: address):
    """
    @notice Set the manager of this contract
    @dev The manager can only set whether the gauge has a counterpart, which allows for
        automatic requests to bridge emissions. Emissions can still be manually bridged and
        the system will still work.
    """
    assert msg.sender == self.owner

    self.manager = _new_manager


@external
def commit_transfer_ownership(_future_owner: address):
    assert msg.sender == self.owner

    self.future_owner = msg.sender


@external
def accept_transfer_ownership():
    assert msg.sender == self.future_owner

    log TransferOwnership(self.owner, msg.sender)
    self.owner = msg.sender


@view
@external
def has_counterpart(_gauge: address) -> bool:
    """
    @notice Boolean denoting whether a gauge has a root counterpart
    """
    return shift(self.gauge_data[_gauge], -128) == 1


@view
@external
def last_request(_gauge: address) -> uint256:
    """
    @notice Timestamp of the last request to bridge emissions for a gauge
    """
    return self.gauge_data[_gauge] % 2 ** 128
