# @version 0.3.1
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
    def owner() -> address: view
    def request_emissions(): nonpayable
    def voting_escrow() -> address: view

interface Minter:
    def minted(_user: address, _gauge: address) -> uint256: view


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


struct Reward:
    token: address
    distributor: address
    period_finish: uint256
    rate: uint256
    last_update: uint256
    integral: uint256


MAX_REWARDS: constant(uint256) = 8
TOKENLESS_PRODUCTION: constant(uint256) = 40
WEEK: constant(uint256) = 86400 * 7

CRV: immutable(address)
MINTER: immutable(address)


name: public(String[64])
symbol: public(String[32])

allowance: public(HashMap[address, HashMap[address, uint256]])
balanceOf: public(HashMap[address, uint256])
totalSupply: public(uint256)

factory: public(address)
lp_token: public(address)
manager: public(address)

voting_escrow: public(address)
working_balances: public(HashMap[address, uint256])
working_supply: public(uint256)

period: public(uint256)
period_timestamp: public(HashMap[uint256, uint256])

integrate_checkpoint_of: public(HashMap[address, uint256])
integrate_fraction: public(HashMap[address, uint256])
integrate_inv_supply: public(HashMap[uint256, uint256])
integrate_inv_supply_of: public(HashMap[address, uint256])

# For tracking external rewards
reward_count: public(uint256)
reward_tokens: public(address[MAX_REWARDS])
reward_data: public(HashMap[address, Reward])
# claimant -> default reward receiver
rewards_receiver: public(HashMap[address, address])
# reward token -> claiming address -> integral
reward_integral_for: public(HashMap[address, HashMap[address, uint256]])
# user -> token -> [uint128 claimable amount][uint128 claimed amount]
claim_data: HashMap[address, HashMap[address, uint256]]

is_killed: public(bool)
last_request: public(uint256)
_inflation_rate: HashMap[uint256, uint256]


@external
def __init__(_crv_token: address, _minter: address):
    self.factory = 0x000000000000000000000000000000000000dEaD

    CRV = _crv_token
    MINTER = _minter


@internal
def _checkpoint(_user: address):
    """
    @notice Checkpoint a user calculating their CRV entitlement
    @param _user User address
    """
    period: uint256 = self.period
    period_time: uint256 = self.period_timestamp[period]
    integrate_inv_supply: uint256 = self.integrate_inv_supply[period]

    current_week: uint256 = block.timestamp / WEEK
    # request emissions for this week (once a week)
    if self.last_request / WEEK < current_week and not self.is_killed:
        Factory(self.factory).request_emissions()
        self.last_request = block.timestamp

    # check CRV balance and increase weekly inflation rate by delta for the rest of the week
    crv_balance: uint256 = ERC20(CRV).balanceOf(self)
    if crv_balance != 0:
        # internal access as may be misleading, inflation rate is increased everytime new rewards come in
        # but really this increase only affects block.timestamp -> end of week, we don't ever
        # really look backwards
        self._inflation_rate[current_week] += crv_balance / ((current_week + 1) * WEEK - block.timestamp)
        ERC20(CRV).transfer(MINTER, crv_balance)

    if block.timestamp > period_time:

        working_supply: uint256 = self.working_supply
        prev_week_time: uint256 = period_time
        week_time: uint256 = min((period_time + WEEK) / WEEK * WEEK, block.timestamp)

        for i in range(256):
            dt: uint256 = week_time - prev_week_time

            if working_supply != 0:
                # we don't have to worry about crossing inflation epochs
                # and if we miss any weeks, those weeks inflation rates will be 0 for sure
                # but that means no one interacted with the gauge for that long
                integrate_inv_supply += self._inflation_rate[prev_week_time / WEEK] * dt / working_supply

            if week_time == block.timestamp:
                break
            prev_week_time = week_time
            week_time = min(week_time + WEEK, block.timestamp)

    period += 1
    self.period = period
    self.period_timestamp[period] = block.timestamp
    self.integrate_inv_supply[period] = integrate_inv_supply

    working_balance: uint256 = self.working_balances[_user]
    self.integrate_fraction[_user] += working_balance * (integrate_inv_supply - self.integrate_inv_supply_of[_user]) / 10 ** 18
    self.integrate_inv_supply_of[_user] = integrate_inv_supply
    self.integrate_checkpoint_of[_user] = block.timestamp


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


@internal
def _checkpoint_rewards(_user: address, _total_supply: uint256, _claim: bool, _receiver: address):
    """
    @notice Claim pending rewards and checkpoint rewards for a user
    """
    user_balance: uint256 = 0
    receiver: address = _receiver
    if _user != ZERO_ADDRESS:
        user_balance = self.balanceOf[_user]
        if _claim and _receiver == ZERO_ADDRESS:
            # if receiver is not explicitly declared, check if a default receiver is set
            receiver = self.rewards_receiver[_user]
            if receiver == ZERO_ADDRESS:
                # if no default receiver is set, direct claims to the user
                receiver = _user

    reward_count: uint256 = self.reward_count
    for i in range(MAX_REWARDS):
        if i == reward_count:
            break
        token: address = self.reward_tokens[i]

        integral: uint256 = self.reward_data[token].integral
        last_update: uint256 = min(block.timestamp, self.reward_data[token].period_finish)
        duration: uint256 = last_update - self.reward_data[token].last_update
        if duration != 0:
            self.reward_data[token].last_update = last_update
            if _total_supply != 0:
                integral += duration * self.reward_data[token].rate * 10**18 / _total_supply
                self.reward_data[token].integral = integral

        if _user != ZERO_ADDRESS:
            integral_for: uint256 = self.reward_integral_for[token][_user]
            new_claimable: uint256 = 0

            if integral_for < integral:
                self.reward_integral_for[token][_user] = integral
                new_claimable = user_balance * (integral - integral_for) / 10**18

            claim_data: uint256 = self.claim_data[_user][token]
            total_claimable: uint256 = shift(claim_data, -128) + new_claimable
            if total_claimable > 0:
                total_claimed: uint256 = claim_data % 2**128
                if _claim:
                    response: Bytes[32] = raw_call(
                        token,
                        _abi_encode(
                            receiver,
                            total_claimable,
                            method_id=method_id("transfer(address,uint256)")
                        ),
                        max_outsize=32,
                    )
                    if len(response) != 0:
                        assert convert(response, bool)
                    self.claim_data[_user][token] = total_claimed + total_claimable
                elif new_claimable > 0:
                    self.claim_data[_user][token] = total_claimed + shift(total_claimable, 128)


@internal
def _transfer(_from: address, _to: address, _value: uint256):
    if _value == 0:
        return
    total_supply: uint256 = self.totalSupply

    has_rewards: bool = self.reward_count != 0
    for addr in [_from, _to]:
        self._checkpoint(addr)
        self._checkpoint_rewards(addr, total_supply, False, ZERO_ADDRESS)

    new_balance: uint256 = self.balanceOf[_from] - _value
    self.balanceOf[_from] = new_balance
    self._update_liquidity_limit(_from, new_balance, total_supply)

    new_balance = self.balanceOf[_to] + _value
    self.balanceOf[_to] = new_balance
    self._update_liquidity_limit(_to, new_balance, total_supply)

    log Transfer(_from, _to, _value)


@external
def deposit(_value: uint256, _user: address = msg.sender):
    """
    @notice Deposit `_value` LP tokens
    @param _value Number of tokens to deposit
    @param _user The account to send gauge tokens to
    """
    self._checkpoint(_user)
    if _value == 0:
        return

    total_supply: uint256 = self.totalSupply + _value
    new_balance: uint256 = self.balanceOf[_user] + _value

    self.balanceOf[_user] = new_balance
    self.totalSupply = total_supply

    self._update_liquidity_limit(_user, new_balance, total_supply)

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
    self._checkpoint(_user)
    if _value == 0:
        return

    total_supply: uint256 = self.totalSupply - _value
    new_balance: uint256 = self.balanceOf[msg.sender] - _value

    self.balanceOf[msg.sender] = new_balance
    self.totalSupply = total_supply

    self._update_liquidity_limit(msg.sender, new_balance, total_supply)

    ERC20(self.lp_token).transfer(_user, _value)

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

    self._transfer(_from, _to, _value)
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
    self._transfer(msg.sender, _to, _value)
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


@external
def user_checkpoint(addr: address) -> bool:
    """
    @notice Record a checkpoint for `addr`
    @param addr User address
    @return bool success
    """
    assert msg.sender in [addr, MINTER]  # dev: unauthorized
    self._checkpoint(addr)
    self._update_liquidity_limit(addr, self.balanceOf[addr], self.totalSupply)
    return True


@external
def claimable_tokens(addr: address) -> uint256:
    """
    @notice Get the number of claimable tokens per user
    @dev This function should be manually changed to "view" in the ABI
    @return uint256 number of claimable tokens per user
    """
    self._checkpoint(addr)
    return self.integrate_fraction[addr] - Minter(MINTER).minted(addr, self)


@view
@external
def claimed_reward(_addr: address, _token: address) -> uint256:
    """
    @notice Get the number of already-claimed reward tokens for a user
    @param _addr Account to get reward amount for
    @param _token Token to get reward amount for
    @return uint256 Total amount of `_token` already claimed by `_addr`
    """
    return self.claim_data[_addr][_token] % 2**128


@view
@external
def claimable_reward(_user: address, _reward_token: address) -> uint256:
    """
    @notice Get the number of claimable reward tokens for a user
    @param _user Account to get reward amount for
    @param _reward_token Token to get reward amount for
    @return uint256 Claimable reward token amount
    """
    integral: uint256 = self.reward_data[_reward_token].integral
    total_supply: uint256 = self.totalSupply
    if total_supply != 0:
        last_update: uint256 = min(block.timestamp, self.reward_data[_reward_token].period_finish)
        duration: uint256 = last_update - self.reward_data[_reward_token].last_update
        integral += (duration * self.reward_data[_reward_token].rate * 10**18 / total_supply)

    integral_for: uint256 = self.reward_integral_for[_reward_token][_user]
    new_claimable: uint256 = self.balanceOf[_user] * (integral - integral_for) / 10**18

    return shift(self.claim_data[_user][_reward_token], -128) + new_claimable


@external
def set_rewards_receiver(_receiver: address):
    """
    @notice Set the default reward receiver for the caller.
    @dev When set to ZERO_ADDRESS, rewards are sent to the caller
    @param _receiver Receiver address for any rewards claimed via `claim_rewards`
    """
    self.rewards_receiver[msg.sender] = _receiver


@external
@nonreentrant('lock')
def claim_rewards(_addr: address = msg.sender, _receiver: address = ZERO_ADDRESS):
    """
    @notice Claim available reward tokens for `_addr`
    @param _addr Address to claim for
    @param _receiver Address to transfer rewards to - if set to
                     ZERO_ADDRESS, uses the default reward receiver
                     for the caller
    """
    if _receiver != ZERO_ADDRESS:
        assert _addr == msg.sender  # dev: cannot redirect when claiming for another user
    self._checkpoint_rewards(_addr, self.totalSupply, True, _receiver)


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
    assert msg.sender == Factory(self.factory).owner()

    self.is_killed = _is_killed


@external
def initialize(_lp_token: address, _manager: address):
    assert self.factory == ZERO_ADDRESS  # dev: already initialzed
    self._checkpoint(ZERO_ADDRESS)
    self._update_liquidity_limit(ZERO_ADDRESS, 0, 0)

    self.factory = msg.sender
    self.lp_token = _lp_token
    self.manager = _manager

    self.voting_escrow = Factory(msg.sender).voting_escrow()

    symbol: String[26] = ERC20Extended(_lp_token).symbol()
    self.name = concat("Curve.fi ", symbol, " Gauge Deposit")
    self.symbol = concat(symbol, "-gauge")


@view
@external
def decimals() -> uint256:
    """
    @notice Returns the number of decimals the token uses
    """
    return 18
