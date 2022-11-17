import asyncio
from starknet_py.contract import Contract
from starknet_py.net.gateway_client import GatewayClient
from starknet_py.net.account.account_client import AccountClient, KeyPair
from starknet_py.transactions.declare import make_declare_tx
from starknet_py.transactions.deploy import make_deploy_tx
from starknet_py.net.models import StarknetChainId
from starknet_py.net.networks import TESTNET, MAINNET

from pathlib import Path
# from base_funcs import *
import sys
import requests
import os

os.environ['CAIRO_PATH'] = 'lib/cairo_contracts/src/'

tokens = []

async def main():
    network_arg = sys.argv[1]
    deploy_token = None

    if network_arg == 'local':
        from config.local import DEPLOYER, deployer_address, router_address
        local_network = "http://127.0.0.1:5050"
        current_client = GatewayClient(local_network, chain=StarknetChainId.TESTNET)
        if deployer_address is None:
            deployer = await AccountClient.create_account(current_client, DEPLOYER)
            mint_json = {"address": hex(deployer.address), "amount": 10**18}
            url = f"{local_network}/mint" 
            x = requests.post(url, json = mint_json)
        else:
            deployer = AccountClient(address=deployer_address, key_pair=KeyPair.from_private_key(DEPLOYER),  net=local_network, chain=StarknetChainId.TESTNET)
        print(f"Deployer Address: {deployer.address}, {hex(deployer.address)}")
    elif network_arg == 'testnet':
        from config.testnet_none import DEPLOYER, deployer_address, router_address, owner_address
        current_client = GatewayClient(TESTNET)
    elif network_arg == 'mainnet':
        from config.mainnet_none import DEPLOYER, deploy_token_mainnet, deployer_address, router_address, owner_address
        current_client = GatewayClient(MAINNET)
        deploy_token = deploy_token_mainnet
    
    
    # deploy Zapper contract 
    deploy_tx = make_deploy_tx(compiled_contract=Path("Zapper.json").read_text(), constructor_calldata=[router_address, owner_address])
    deployment_result = await current_client.deploy(deploy_tx, token=deploy_token)
    await current_client.wait_for_tx(deployment_result.transaction_hash)
    zapper_address = deployment_result.contract_address

    print(f"Zapper deployed: {zapper_address}, {hex(zapper_address)}")


    # deploy ZapperOut contract 
    deploy_tx = make_deploy_tx(compiled_contract=Path("ZapperOut.json").read_text(), constructor_calldata=[router_address, owner_address])
    deployment_result = await current_client.deploy(deploy_tx, token=deploy_token)
    await current_client.wait_for_tx(deployment_result.transaction_hash)
    zapperOut_address = deployment_result.contract_address
    print(f"ZapperOut deployed: {zapperOut_address}, {hex(zapperOut_address)}")


if __name__ == "__main__":
    asyncio.run(main())
