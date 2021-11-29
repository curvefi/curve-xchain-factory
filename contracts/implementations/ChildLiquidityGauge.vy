# @version 0.3.0
"""
@title Child Liquidity Gauge
@license MIT
@author Curve Finance
"""
from vyper.interfaces import ERC20

implements: ERC20


interface ERC20Extended:
    def symbol() -> String[26]: view

interface Factory:
    def inflation_params_write() -> InflationParams: nonpayable
    def owner() -> address: view
    def voting_escrow() -> address: view


event Approval:
    _owner: indexed(address)
    _spender: indexed(address)
    _value: uint256

event Transfer:
    _from: indexed(address)
    _to: indexed(address)
    _value: uint256

event Deposit:
    _user: indexed(address)
    _value: uint256

event Withdraw:
    _user: indexed(address)
    _value: uint256

event UpdateLiquidityLimit:
    _user: indexed(address)
    _original_balance: uint256
    _original_supply: uint256
    _working_balance: uint256
    _working_supply: uint256


struct InflationParams:
    rate: uint256
    finish_time: uint256


TOKENLESS_PRODUCTION: constant(uint256) = 40


name: public(String[64])
symbol: public(String[32])

allowance: public(HashMap[address, HashMap[address, uint256]])
balanceOf: public(HashMap[address, uint256])
totalSupply: public(uint256)

factory: public(address)
inflation_params: public(InflationParams)
lp_token: public(address)
manager: public(address)

voting_escrow: public(address)
working_balances: public(HashMap[address, uint256])
working_supply: public(uint256)

is_killed: public(bool)


@external
def __init__():
    self.factory = 0x000000000000000000000000000000000000dEaD


@internal
def _update_liquidity_limit(_user: address, _user_balance: uint256, _total_supply: uint256):
    """
    @notice Calculate working balances to apply amplification of CRV production.
    @dev https://resources.curve.fi/guides/boosting-your-crv-rewards#formula
    @param _user The user address
    @param _user_balance User's amount of liquidity (LP tokens)
    @param _total_supply Total amount of liquidity (LP tokens)
    """
    working_balance: uint256 = _user_balance * TOKENLESS_PRODUCTION / 100

    ve: address = self.voting_escrow
    if ve != ZERO_ADDRESS:
        ve_ts: uint256 = ERC20(ve).totalSupply()
        if ve_ts != 0:
            working_balance += _total_supply * ERC20(ve).balanceOf(_user) / ve_ts * (100 - TOKENLESS_PRODUCTION) / 100
            working_balance = min(_user_balance, working_balance)

    old_working_balance: uint256 = self.working_balances[_user]
    self.working_balances[_user] = working_balance

    working_supply: uint256 = self.working_supply + working_balance - old_working_balance
    self.working_supply = working_supply

    log UpdateLiquidityLimit(_user, _user_balance, _total_supply, working_balance, working_supply)


@external
def deposit(_value: uint256, _user: address = msg.sender):
    """
    @notice Deposit `_value` LP tokens
    @param _value Number of tokens to deposit
    @param _user The account to send gauge tokens to
    """
    if _value == 0:
        return
    self.balanceOf[_user] += _value
    self.totalSupply += _value

    ERC20(self.lp_token).transferFrom(msg.sender, self, _value)
    log Deposit(_user, _value)
    log Transfer(ZERO_ADDRESS, _user, _value)


@external
def withdraw(_value: uint256, _user: address = msg.sender):
    """
    @notice Withdraw `_value` LP tokens
    @param _value Number of tokens to withdraw
    @param _user The account to send LP tokens to
    """
    if _value == 0:
        return
    self.balanceOf[msg.sender] -= _value
    self.totalSupply -= _value

    ERC20(self.lp_token).transferFrom(self, _user, _value)
    log Withdraw(_user, _value)
    log Transfer(msg.sender, ZERO_ADDRESS, _value)


@external
def transferFrom(_from: address, _to: address, _value: uint256) -> bool:
    """
    @notice Transfer tokens from one address to another
    @param _from The address which you want to send tokens from
    @param _to The address which you want to transfer to
    @param _value the amount of tokens to be transferred
    @return bool success
    """
    allowance: uint256 = self.allowance[_from][msg.sender]
    if allowance != MAX_UINT256:
        self.allowance[_from][msg.sender] = allowance - _value

    self.balanceOf[_from] -= _value
    self.balanceOf[_to] += _value

    log Transfer(_from, _to, _value)
    return True


@external
def approve(_spender: address, _value: uint256) -> bool:
    """
    @notice Approve the passed address to transfer the specified amount of
            tokens on behalf of msg.sender
    @dev Beware that changing an allowance via this method brings the risk
         that someone may use both the old and new allowance by unfortunate
         transaction ordering. This may be mitigated with the use of
         {increaseAllowance} and {decreaseAllowance}.
         https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    @param _spender The address which will transfer the funds
    @param _value The amount of tokens that may be transferred
    @return bool success
    """
    self.allowance[msg.sender][_spender] = _value

    log Approval(msg.sender, _spender, _value)
    return True


@external
def transfer(_to: address, _value: uint256) -> bool:
    """
    @notice Transfer token to a specified address
    @param _to The address to transfer to
    @param _value The amount to be transferred
    @return bool success
    """
    self.balanceOf[msg.sender] -= _value
    self.balanceOf[_to] += _value

    log Transfer(msg.sender, _to, _value)
    return True


@external
def increaseAllowance(_spender: address, _added_value: uint256) -> bool:
    """
    @notice Increase the allowance granted to `_spender` by the caller
    @dev This is alternative to {approve} that can be used as a mitigation for
         the potential race condition
    @param _spender The address which will transfer the funds
    @param _added_value The amount of to increase the allowance
    @return bool success
    """
    allowance: uint256 = self.allowance[msg.sender][_spender] + _added_value
    self.allowance[msg.sender][_spender] = allowance

    log Approval(msg.sender, _spender, allowance)
    return True


@external
def decreaseAllowance(_spender: address, _subtracted_value: uint256) -> bool:
    """
    @notice Decrease the allowance granted to `_spender` by the caller
    @dev This is alternative to {approve} that can be used as a mitigation for
         the potential race condition
    @param _spender The address which will transfer the funds
    @param _subtracted_value The amount of to decrease the allowance
    @return bool success
    """
    allowance: uint256 = self.allowance[msg.sender][_spender] - _subtracted_value
    self.allowance[msg.sender][_spender] = allowance

    log Approval(msg.sender, _spender, allowance)
    return True


@view
@external
def decimals() -> uint256:
    """
    @notice Returns the number of decimals the token uses
    """
    return 18


@external
def update_voting_escrow():
    """
    @notice Update the voting escrow contract in storage
    """
    self.voting_escrow = Factory(self.factory).voting_escrow()


@external
def set_killed(_is_killed: bool):
    """
    @notice Set the kill status of the gauge
    @param _is_killed Kill status to put the gauge into
    """
    factory: address = self.factory
    assert msg.sender == Factory(factory).owner()

    if _is_killed:
        self.inflation_params = empty(InflationParams)
    else:
        self.inflation_params = Factory(factory).inflation_params_write()
    self.is_killed = _is_killed


@external
def initialize(_lp_token: address, _manager: address, _inflation_params: InflationParams):
    assert self.factory == ZERO_ADDRESS  # dev: already initialzed

    self.factory = msg.sender
    self.inflation_params = _inflation_params
    self.lp_token = _lp_token
    self.manager = _manager

    self.voting_escrow = Factory(msg.sender).voting_escrow()

    symbol: String[26] = ERC20Extended(_lp_token).symbol()
    self.name = concat("Curve.fi ", symbol, " Gauge Deposit")
    self.symbol = concat(symbol, "-gauge")