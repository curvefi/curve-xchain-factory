# pragma version 0.3.10
"""
@title Root Gauge Factory Proxy Owner
@license MIT
@author CurveFi
@custom:version 1.0.1
"""

version: public(constant(String[8])) = "1.0.1"


interface Factory:
    def accept_transfer_ownership(): nonpayable
    def commit_transfer_ownership(_future_owner: address): nonpayable
    def set_child(_chain_id: uint256, _bridger: address, _child_factory: address, _child_impl: address): nonpayable
    def set_bridger(_chain_id: uint256, _bridger: address): nonpayable
    def set_call_proxy(_new_call_proxy: address): nonpayable
    def set_implementation(_implementation: address): nonpayable

interface LiquidityGauge:
    def set_killed(_killed: bool): nonpayable
    def set_child_gauge(_child: address): nonpayable


event CommitAdmins:
    ownership_admin: indexed(address)
    emergency_admin: indexed(address)

event ApplyAdmins:
    ownership_admin: indexed(address)
    emergency_admin: indexed(address)

event SetManager:
    _manager: indexed(address)


ownership_admin: public(address)
emergency_admin: public(address)

future_ownership_admin: public(address)
future_emergency_admin: public(address)

manager: public(address)


@external
def __init__():
    self.ownership_admin = 0x40907540d8a6C65c637785e8f8B742ae6b0b9968
    self.emergency_admin = 0x467947EE34aF926cF1DCac093870f613C96B1E0c

    self.manager = msg.sender
    log SetManager(msg.sender)


@external
def commit_set_admins(_o_admin: address, _e_admin: address):
    """
    @notice Set ownership admin to `_o_admin` and emergency admin to `_e_admin`
    @param _o_admin Ownership admin
    @param _e_admin Emergency admin
    """
    assert msg.sender == self.ownership_admin, "Access denied"

    self.future_ownership_admin = _o_admin
    self.future_emergency_admin = _e_admin

    log CommitAdmins(_o_admin, _e_admin)


@external
def accept_set_admins():
    """
    @notice Apply the effects of `commit_set_admins`
    @dev Only callable by the new owner admin
    """
    assert msg.sender == self.future_ownership_admin, "Access denied"

    e_admin: address = self.future_emergency_admin
    self.ownership_admin = msg.sender
    self.emergency_admin = e_admin

    log ApplyAdmins(msg.sender, e_admin)


@external
def set_manager(_new_manager: address):
    """
    @notice Set the manager account which is not capable of killing gauges.
    @param _new_manager The new manager account
    """
    assert msg.sender in [self.ownership_admin, self.emergency_admin, self.manager]
    self.manager = _new_manager
    log SetManager(_new_manager)


@external
def commit_transfer_ownership(_factory: Factory, _new_owner: address):
    """
    @notice Transfer ownership for factory `_factory` to `new_owner`
    @param _factory Factory which ownership is to be transferred
    @param _new_owner New factory owner address
    """
    assert msg.sender == self.ownership_admin, "Access denied"
    _factory.commit_transfer_ownership(_new_owner)


@external
def accept_transfer_ownership(_factory: Factory):
    """
    @notice Apply transferring ownership of `_factory`
    @param _factory Factory address
    """
    _factory.accept_transfer_ownership()


@external
def set_child_gauge(_root: LiquidityGauge, _child: address):
    """
    @notice Set child gauge address to bridge coins to
    @param _root Root gauge address
    @param _child Child gauge address
    """
    assert msg.sender == self.ownership_admin, "Access denied"

    _root.set_child_gauge(_child)


@external
def set_killed(_gauge: LiquidityGauge, _is_killed: bool):
    """
    @notice Set the killed status for `_gauge`
    @dev When killed, the gauge always yields a rate of 0 and so cannot mint CRV
    @param _gauge Gauge address
    @param _is_killed Killed status to set
    """
    assert msg.sender in [self.ownership_admin, self.emergency_admin], "Access denied"

    _gauge.set_killed(_is_killed)


@external
def set_child(_factory: Factory, _chain_id: uint256, _bridger: address, _child_factory: address, _child_impl: address):
    """
    @notice Set contracts used for `_chain_id` on `_factory`
    """
    assert msg.sender in [self.ownership_admin, self.manager]

    _factory.set_child(_chain_id, _bridger, _child_factory, _child_impl)


@external
def set_bridger(_factory: Factory, _chain_id: uint256, _bridger: address):
    """
    @notice Set the bridger used for `_chain_id` on `_factory`, for older implementation
    """
    assert msg.sender in [self.ownership_admin, self.manager]

    _factory.set_bridger(_chain_id, _bridger)


@external
def set_implementation(_factory: Factory, _implementation: address):
    """
    @notice Set the gauge implementation used by `_factory`
    """
    assert msg.sender in [self.ownership_admin, self.manager]

    _factory.set_implementation(_implementation)


@external
def set_call_proxy(_factory: Factory, _new_call_proxy: address):
    """
    @notice Set the call proxy messenger used by `_factory`
    """
    assert msg.sender in [self.ownership_admin, self.manager]

    _factory.set_call_proxy(_new_call_proxy)
