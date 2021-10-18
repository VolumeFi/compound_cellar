#!/usr/bin/python3

import pytest, time

from eth_abi import encode_abi

def test_deposit_withdraw(USDC, WETH, accounts, SwapRouter, compoundcellarContract, Contract):
    SwapRouter.exactOutputSingle([WETH, USDC, 3000, accounts[0], 2 ** 256 - 1, 6000 * 10 ** 6, 6 * 10 ** 18, 0], {"from": accounts[0], "value": 6 * 10 ** 18})
    USDC.approve(compoundcellarContract, 6000 * 10 ** 6, {"from": accounts[0]})
    USDC_amount = 1000 * 10 ** 6
    compoundcellarContract.deposit(USDC_amount, {"from": accounts[0]})
    print(compoundcellarContract.balanceOf(accounts[0]))
    compoundcellarContract.withdraw(USDC_amount / 2, {"from": accounts[0]})
    print(compoundcellarContract.balanceOf(accounts[0]))

def test_harvest(USDC, USDT, WETH, accounts, SwapRouter, compoundcellarContract, COMP, CUSDC, Contract):
    SwapRouter.exactOutputSingle([WETH, USDC, 3000, accounts[0], 2 ** 256 - 1, 6000 * 10 ** 6, 6 * 10 ** 18, 0], {"from": accounts[0], "value": 6 * 10 ** 18})
    USDC.approve(compoundcellarContract, 6000 * 10 ** 6, {"from": accounts[0]})
    USDC_amount = 1000 * 10 ** 6
    compoundcellarContract.deposit(USDC_amount, {"from": accounts[0]})
    compoundcellarContract.deposit(USDC_amount, {"from": accounts[0]})
    print(CUSDC.balanceOf(compoundcellarContract))
    compoundcellarContract.harvest(0, {"from": accounts[0]})

def test_reinvest(USDC, USDT, WETH, accounts, SwapRouter, compoundcellarContract, COMP, CUSDC, Contract):
    encode_data = encode_abi(['address', 'uint256', 'uint256', 'uint256','uint256', 'uint256', 'uint256', 'uint256'], [WETH.address, 3000, 0, 0, 0, 0, 0, 0]).hex()
    compoundcellarContract.reinvest("0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5", encode_data, 0, {"from": accounts[0]})
    bal = compoundcellarContract.balanceOf(accounts[0])
    print(bal)
    compoundcellarContract.withdraw(bal, {"from": accounts[0]})
    print(compoundcellarContract.balanceOf(accounts[0]))
    compoundcellarContract.deposit(10 ** 18, {"from": accounts[0], "value": 10 ** 18})
    print(compoundcellarContract.balanceOf(accounts[0]))