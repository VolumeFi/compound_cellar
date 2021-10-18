# @version ^0.3.0

event Transfer:
    _from: indexed(address)
    _to: indexed(address)
    _value: uint256

event Approval:
    _owner: indexed(address)
    _spender: indexed(address)
    _value: uint256

event Payment:
    sender: indexed(address)
    amount: uint256

name: public(String[64])
symbol: public(String[32])

balanceOf: public(HashMap[address, uint256])
allowance: public(HashMap[address, HashMap[address, uint256]])
totalSupply: public(uint256)

validators: public(HashMap[address, bool])
u_token: public(address)
c_token: public(address)
owner: public(address)
serviceFee: public(uint256)

APPROVE_MID: constant(Bytes[4]) = method_id("approve(address,uint256)")
TRANSFER_MID: constant(Bytes[4]) = method_id("transfer(address,uint256)")
TRANSFERFROM_MID: constant(Bytes[4]) = method_id("transferFrom(address,address,uint256)")
DEPOSIT_MID: constant(Bytes[4]) = method_id("deposit(address,uint256,address,uint16)")
GRD_MID: constant(Bytes[4]) = method_id("getReserveData(address)")
EIS_MID: constant(Bytes[4]) = method_id("exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))")
CLM_MID: constant(Bytes[4]) = method_id("claimComp(address,address[])")

COMPTROLLER: constant(address) = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B
SWAPROUTER: constant(address) = 0xE592427A0AEce92De3Edee1F18E0157C05861564
FEE_DOMINATOR: constant(uint256) = 10000
COMP: constant(address) = 0xc00e94Cb662C3520282E6f5717214004A7f26888
WETH: constant(address) = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
cETH: constant(address) = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5

interface WrappedEth:
    def deposit(): payable
    def withdraw(amount: uint256): nonpayable

interface ERC20:
    def balanceOf(_to: address) -> uint256: view

interface CERC20:
    def underlying() -> address: view
    def mint(amount: uint256) -> uint256: nonpayable
    def redeem(amount: uint256) -> uint256: nonpayable

interface CEther:
    def mint(): payable

interface Comptroller:
    def exitMarket(cToken: address) -> uint256: nonpayable

@external
def __init__(_name: String[64], _symbol: String[32], _c_Token: address):
    self.name = _name
    self.symbol = _symbol
    self.c_token = _c_Token
    self.serviceFee = 50
    if _c_Token != cETH:
        self.u_token = CERC20(_c_Token).underlying()
    self.owner = msg.sender
    self.validators[msg.sender] = True

@internal
def _mint(_to: address, _value: uint256):
    assert _to != ZERO_ADDRESS, "mint to zero address"
    self.totalSupply += _value
    self.balanceOf[_to] += _value
    log Transfer(ZERO_ADDRESS, _to, _value)

@internal
def _burn(_to: address, _value: uint256):
    assert _to != ZERO_ADDRESS, "burn from zero address"
    self.totalSupply -= _value
    self.balanceOf[_to] -= _value
    log Transfer(_to, ZERO_ADDRESS, _value)

@internal
def safe_approve(_token: address, _to: address, _value: uint256):
    _response: Bytes[32] = raw_call(
        _token,
        concat(
            APPROVE_MID,
            convert(_to, bytes32),
            convert(_value, bytes32)
        ),
        max_outsize=32
    )  # dev: failed approve
    if len(_response) > 0:
        assert convert(_response, bool) # dev: failed approve

@internal
def safe_transfer(_token: address, _to: address, _value: uint256):
    _response: Bytes[32] = raw_call(
        _token,
        concat(
            TRANSFER_MID,
            convert(_to, bytes32),
            convert(_value, bytes32)
        ),
        max_outsize=32
    )  # dev: failed transfer
    if len(_response) > 0:
        assert convert(_response, bool) # dev: failed transfer

@internal
def safe_transfer_from(_token: address, _from: address, _to: address, _value: uint256):
    _response: Bytes[32] = raw_call(
        _token,
        concat(
            TRANSFERFROM_MID,
            convert(_from, bytes32),
            convert(_to, bytes32),
            convert(_value, bytes32)
        ),
        max_outsize=32
    )  # dev: failed transfer from
    if len(_response) > 0:
        assert convert(_response, bool) # dev: failed transfer from

@internal
def _token2Token(fromToken: address, toToken: address, feeLevel: uint256, tokens2Trade: uint256, deadline: uint256) -> uint256:
    if fromToken == toToken:
        return tokens2Trade
    self.safe_approve(fromToken, SWAPROUTER, tokens2Trade)
    _response: Bytes[32] = raw_call(
        SWAPROUTER,
        concat(
            EIS_MID,
            convert(fromToken, bytes32),
            convert(toToken, bytes32),
            convert(feeLevel, bytes32),
            convert(self, bytes32),
            convert(deadline, bytes32),
            convert(tokens2Trade, bytes32),
            convert(0, bytes32),
            convert(0, bytes32)
        ),
        max_outsize=32
    )
    tokenBought: uint256 = convert(_response, uint256)
    self.safe_approve(fromToken, SWAPROUTER, 0)
    assert tokenBought > 0, "Error Swapping Token"
    return tokenBought

@external
@pure
def decimals() -> uint256:
    return 18

@external
def transfer(_to : address, _value : uint256) -> bool:
    assert _to != ZERO_ADDRESS # dev: zero address
    self.balanceOf[msg.sender] -= _value
    self.balanceOf[_to] += _value
    log Transfer(msg.sender, _to, _value)
    return True

@external
def transferFrom(_from : address, _to : address, _value : uint256) -> bool:
    assert _to != ZERO_ADDRESS # dev: zero address
    self.balanceOf[_from] -= _value
    self.balanceOf[_to] += _value
    self.allowance[_from][msg.sender] -= _value
    log Transfer(_from, _to, _value)
    return True

@external
def approve(_spender : address, _value : uint256) -> bool:
    assert _value == 0 or self.allowance[msg.sender][_spender] == 0
    self.allowance[msg.sender][_spender] = _value
    log Approval(msg.sender, _spender, _value)
    return True

@external
def increaseAllowance(_spender: address, _value: uint256) -> bool:
    allowance: uint256 = self.allowance[msg.sender][_spender]
    allowance += _value
    self.allowance[msg.sender][_spender] = allowance
    log Approval(msg.sender, _spender, allowance)
    return True

@external
def decreaseAllowance(_spender: address, _value: uint256) -> bool:
    allowance: uint256 = self.allowance[msg.sender][_spender]
    allowance -= _value
    self.allowance[msg.sender][_spender] = allowance
    log Approval(msg.sender, _spender, allowance)
    return True

@external
@payable
@nonreentrant('lock')
def deposit(amount: uint256):
    assert amount > 0, "Can not deposit 0 amount"
    _uToken: address = self.u_token
    _cToken: address = self.c_token
    if msg.value > 0:
        if _cToken == cETH:
            if msg.value > amount:
                send(msg.sender, msg.value - amount)
            elif msg.value < amount:
                raise "Insufficient amount"
        else:
            self.safe_transfer_from(_uToken, msg.sender, self, amount)
            send(msg.sender, msg.value)
    else:
        self.safe_transfer_from(_uToken, msg.sender, self, amount)

    fee: uint256 = amount * self.serviceFee / FEE_DOMINATOR
    if _cToken == cETH:
        send(self.owner, fee)
    else:
        self.safe_transfer(_uToken, self.owner, fee)
    real_amount: uint256 = amount - fee

    c_token_balance: uint256 = ERC20(_cToken).balanceOf(self)
    if _cToken == cETH:
        CEther(cETH).mint(value=real_amount)
    else:
        self.safe_approve(self.u_token, _cToken, real_amount)
        CERC20(_cToken).mint(real_amount)
    c_token_new_balance: uint256 = ERC20(_cToken).balanceOf(self)
    _total_supply: uint256 = self.totalSupply
    if c_token_balance == 0 or _total_supply == 0:
        self._mint(msg.sender, c_token_new_balance - c_token_balance)
    else:
        self._mint(msg.sender, (c_token_new_balance - c_token_balance) * _total_supply / c_token_balance)

@external
@nonreentrant('lock')
def withdraw(amount: uint256):
    _cToken: address = self.c_token
    if _cToken == cETH:
        bal: uint256 = self.balance
        CERC20(_cToken).redeem(amount * ERC20(_cToken).balanceOf(self) / self.totalSupply)
        bal = self.balance - bal
        send(msg.sender, bal)
    else:
        _uToken: address = self.u_token
        bal: uint256 = ERC20(_uToken).balanceOf(self)
        CERC20(_cToken).redeem(amount * ERC20(_cToken).balanceOf(self) / self.totalSupply)
        bal = ERC20(_uToken).balanceOf(self) - bal
        self.safe_transfer(_uToken, msg.sender, bal)
    self._burn(msg.sender, amount)

@external
def reinvest(newCToken: address, route: Bytes[256], minPrice: uint256):
    assert msg.sender == self.owner
    _cToken: address = self.c_token
    amount: uint256 = ERC20(_cToken).balanceOf(self)
    _uToken: address = self.u_token
    # Comptroller(COMPTROLLER).exitMarket(_cToken)
    CERC20(_cToken).redeem(amount)
    amount = ERC20(_uToken).balanceOf(self)
    old_amount: uint256 = amount
    for i in range(4):
        uToken: address = convert(convert(slice(route, i * 64, 32), uint256), address)
        feeLevel: uint256 = convert(slice(route, i * 64 + 32, 32), uint256)
        if uToken == ZERO_ADDRESS:
            assert i != 0, "Route Error"
            break
        amount = self._token2Token(_uToken, uToken, feeLevel, amount, block.timestamp)
        _uToken = uToken
    if newCToken == cETH:
        assert _uToken == WETH, "Token match error"
        WrappedEth(WETH).withdraw(amount)
        CEther(cETH).mint(value=amount)
        self.u_token = ZERO_ADDRESS
    else:
        assert _uToken == CERC20(newCToken).underlying(), "Token match error"
        self.safe_approve(_uToken, newCToken, amount)
        CERC20(newCToken).mint(amount)
        self.u_token = _uToken
    assert old_amount * minPrice <= amount * 10 ** 18, "High Slippage"
    self.c_token = newCToken

@external
def harvest(minPrice: uint256):
    assert self.validators[msg.sender], "Not validator"
    raw_call(
        COMPTROLLER,
        concat(
            CLM_MID,
            convert(self, bytes32),
            convert(64, bytes32),
            convert(1, bytes32),
            convert(self.c_token, bytes32)
        )
    )
    old_amount: uint256 = ERC20(COMP).balanceOf(self)
    if old_amount > 0:
        amount: uint256 = self._token2Token(COMP, WETH, 3000, old_amount, block.timestamp)
        assert old_amount * minPrice <= amount * 10 ** 18, "High Slippage"
        _cToken: address = self.c_token
        if _cToken != cETH:
            _uToken: address = self.u_token
            amount = self._token2Token(WETH, _uToken, 3000, amount, block.timestamp)
            self.safe_approve(_uToken, _cToken, amount)
            CERC20(_cToken).mint(amount)
        else:
            WrappedEth(WETH).withdraw(amount)
            CEther(cETH).mint(value=amount)

@external
def setValidator(_validator: address, _value: bool):
    assert msg.sender == self.owner and _validator != ZERO_ADDRESS
    self.validators[_validator] = _value

@external
def transferOwnership(_owner: address):
    assert msg.sender == self.owner
    self.owner = _owner

@external
def setServiceFee(_serviceFee: uint256):
    assert msg.sender == self.owner
    self.serviceFee = _serviceFee

@external
@payable
def __default__():
    log Payment(msg.sender, msg.value)