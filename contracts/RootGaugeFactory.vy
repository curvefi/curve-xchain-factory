# pragma version 0.3.10
"""
@title Root Liquidity Gauge Factory
@license MIT
@author Curve Finance
@custom:version 1.0.1
"""

version: public(constant(String[8])) = "1.0.1"


interface Bridger:
    def check(_addr: address) -> bool: view

interface RootGauge:
    def bridger() -> Bridger: view
    def initialize(_bridger: Bridger, _chain_id: uint256, _child: address): nonpayable
    def transmit_emissions(): nonpayable

interface CallProxy:
    def anyCall(
        _to: address, _data: Bytes[1024], _fallback: address, _to_chain_id: uint256
    ): nonpayable

event ChildUpdated:
    _chain_id: indexed(uint256)
    _new_bridger: Bridger
    _new_factory: address
    _new_implementation: address

event DeployedGauge:
    _implementation: indexed(address)
    _chain_id: indexed(uint256)
    _deployer: indexed(address)
    _salt: bytes32
    _gauge: RootGauge

event TransferOwnership:
    _old_owner: address
    _new_owner: address

event UpdateCallProxy:
    _old_call_proxy: CallProxy
    _new_call_proxy: CallProxy

event UpdateImplementation:
    _old_implementation: address
    _new_implementation: address


call_proxy: public(CallProxy)
get_bridger: public(HashMap[uint256, Bridger])
get_child_factory: public(HashMap[uint256, address])
get_child_implementation: public(HashMap[uint256, address])
get_implementation: public(address)

get_gauge: public(HashMap[uint256, RootGauge[max_value(uint256)]])
get_gauge_count: public(HashMap[uint256, uint256])
is_valid_gauge: public(HashMap[RootGauge, bool])

owner: public(address)
future_owner: public(address)


@external
def __init__(_call_proxy: CallProxy, _owner: address):
    self.call_proxy = _call_proxy
    log UpdateCallProxy(empty(CallProxy), _call_proxy)

    self.owner = _owner
    log TransferOwnership(empty(address), _owner)


@external
def transmit_emissions(_gauge: RootGauge):
    """
    @notice Call `transmit_emissions` on a root gauge
    @dev Entrypoint for anycall to request emissions for a child gauge.
        The way that gauges work, this can also be called on the root
        chain without a request.
    """
    # in most cases this will return True
    # for special bridges *cough cough Multichain, we can only do
    # one bridge per tx, therefore this will verify msg.sender in [tx.origin, self.call_proxy]
    assert _gauge.bridger().check(msg.sender)
    _gauge.transmit_emissions()


@internal
def _get_child(_chain_id: uint256, salt: bytes32) -> address:
    """
    @dev zkSync address derivation is ignored, so need to set child address through a vote manually
    """
    child_factory: address = self.get_child_factory[_chain_id]
    child_impl: bytes20 = convert(self.get_child_implementation[_chain_id], bytes20)

    assert child_factory != empty(address)  # dev: child factory not set
    assert child_impl != empty(bytes20)  # dev: child implementation not set

    gauge_codehash: bytes32 = keccak256(
        concat(0x602d3d8160093d39f3363d3d373d3d3d363d73, child_impl, 0x5af43d82803e903d91602b57fd5bf3))
    digest: bytes32 = keccak256(concat(0xFF, convert(child_factory, bytes20), salt, gauge_codehash))
    return convert(convert(digest, uint256) & convert(max_value(uint160), uint256), address)


@payable
@external
def deploy_gauge(_chain_id: uint256, _salt: bytes32) -> RootGauge:
    """
    @notice Deploy a root liquidity gauge
    @param _chain_id The chain identifier of the counterpart child gauge
    @param _salt A value to deterministically deploy a gauge
    """
    bridger: Bridger = self.get_bridger[_chain_id]
    assert bridger != empty(Bridger)  # dev: chain id not supported

    implementation: address = self.get_implementation
    salt: bytes32 = keccak256(_abi_encode(_chain_id, _salt))
    gauge: RootGauge = RootGauge(create_minimal_proxy_to(
        implementation,
        value=msg.value,
        salt=salt,
    ))
    child: address = self._get_child(_chain_id, salt)

    idx: uint256 = self.get_gauge_count[_chain_id]
    self.get_gauge[_chain_id][idx] = gauge
    self.get_gauge_count[_chain_id] = idx + 1
    self.is_valid_gauge[gauge] = True

    gauge.initialize(bridger, _chain_id, child)

    log DeployedGauge(implementation, _chain_id, msg.sender, _salt, gauge)
    return gauge


@external
def deploy_child_gauge(_chain_id: uint256, _lp_token: address, _salt: bytes32, _manager: address = msg.sender):
    bridger: Bridger = self.get_bridger[_chain_id]
    assert bridger != empty(Bridger)  # dev: chain id not supported

    self.call_proxy.anyCall(
        self,
        _abi_encode(
            _lp_token,
            _salt,
            _manager,
            method_id=method_id("deploy_gauge(address,bytes32,address)")
        ),
        empty(address),
        _chain_id
    )


@external
def set_child(_chain_id: uint256, _bridger: Bridger, _child_factory: address, _child_impl: address):
    """
    @notice Set the bridger for `_chain_id`
    @param _chain_id The chain identifier to set the bridger for
    @param _bridger The bridger contract to use
    @param _child_factory Address of factory on L2 (needed in price derivation)
    @param _child_impl Address of gauge implementation on L2 (needed in price derivation)
    """
    assert msg.sender == self.owner  # dev: only owner

    log ChildUpdated(_chain_id, _bridger, _child_factory, _child_impl)
    self.get_bridger[_chain_id] = _bridger
    self.get_child_factory[_chain_id] = _child_factory
    self.get_child_implementation[_chain_id] = _child_impl


@external
def set_implementation(_implementation: address):
    """
    @notice Set the implementation
    @dev Changing implementation require change on all child factories
    @param _implementation The address of the implementation to use
    """
    assert msg.sender == self.owner  # dev: only owner

    log UpdateImplementation(self.get_implementation, _implementation)
    self.get_implementation = _implementation


@external
def set_call_proxy(_call_proxy: CallProxy):
    """
    @notice Set CallProxy
    @param _call_proxy Contract to use for inter-chain communication
    """
    assert msg.sender == self.owner

    self.call_proxy = _call_proxy
    log UpdateCallProxy(empty(CallProxy), _call_proxy)


@external
def commit_transfer_ownership(_future_owner: address):
    """
    @notice Transfer ownership to `_future_owner`
    @param _future_owner The account to commit as the future owner
    """
    assert msg.sender == self.owner  # dev: only owner

    self.future_owner = _future_owner


@external
def accept_transfer_ownership():
    """
    @notice Accept the transfer of ownership
    @dev Only the committed future owner can call this function
    """
    assert msg.sender == self.future_owner  # dev: only future owner

    log TransferOwnership(self.owner, msg.sender)
    self.owner = msg.sender
