  
from brownie import compoundcellar, accounts

def main():
    acct = accounts.load("deployer_account")
    name = "Compound Cellar Pool Share Token"
    symbol = "CCS"
    c_token = "0x39AA39c021dfbaE8faC545936693aC917d5E7563"
    compoundcellar.deploy(name, symbol, c_token, {"from":acct})