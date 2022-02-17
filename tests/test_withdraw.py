from secrets import token_urlsafe
import pytest
import asyncio
import math

def uint(a):
    return(a, 0)


@pytest.mark.asyncio
async def test_withdraw_zap_in(deployer,starknet,zapper, router, pair, token_0, token_1,token_2, user_1,user_2, random_acc):
    user_2_signer, user_2_account = user_2
    random_signer, random_account = random_acc
    deployer_signer, deployer_account = deployer
    
    print("\nMint loads of tokens to zapper contract ")
    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_to_mint_token_0 = 100 * (10 ** token_0_decimals)
    ## Mint token_0 to user_2
    await random_signer.send_transaction(random_account, token_0.contract_address, 'mint', [zapper.contract_address, *uint(amount_to_mint_token_0)])
    
    execution_info = await token_1.decimals().call()
    token_1_decimals = execution_info.result.decimals
    amount_to_mint_token_1 = 150 * (10 ** token_1_decimals)
    ## Mint token_1 to user_2
    await random_signer.send_transaction(random_account, token_1.contract_address, 'mint', [zapper.contract_address, *uint(amount_to_mint_token_1)])
    
    
    execution_info = await token_2.decimals().call()
    token_2_decimals = execution_info.result.decimals
    amount_to_mint_token_2 = 80 * (10 ** token_2_decimals)
    ## Mint token_2 to user_2
    await random_signer.send_transaction(random_account, token_2.contract_address, 'mint', [zapper.contract_address, *uint(amount_to_mint_token_2)])
    
    execution_info = await deployer_signer.send_transaction(deployer_account, zapper.contract_address, 'withdraw_tokens', [
        3,
        token_0.contract_address, 
        token_1.contract_address,
        token_2.contract_address
        
    ])
    
    execution_info = await token_0.balanceOf(deployer_account.contract_address).call()
    deployer_token0_balance = execution_info.result.balance[0]
    print(f"{deployer_token0_balance}")
    
    execution_info = await token_1.balanceOf(deployer_account.contract_address).call()
    deployer_token1_balance = execution_info.result.balance[0]
    print(f"{deployer_token1_balance}")
    
    execution_info = await token_2.balanceOf(deployer_account.contract_address).call()
    deployer_token2_balance = execution_info.result.balance[0]
    print(f"{deployer_token2_balance}")
    
    assert deployer_token0_balance == amount_to_mint_token_0
    assert deployer_token1_balance == amount_to_mint_token_1
    assert deployer_token2_balance == amount_to_mint_token_2
    
@pytest.mark.asyncio    
async def test_withdraw_zap_out(deployer,starknet,zapper_out, router, pair, token_0, token_1,token_2, user_1,user_2, random_acc):
    user_2_signer, user_2_account = user_2
    random_signer, random_account = random_acc
    deployer_signer, deployer_account = deployer
    
    print("\nMint loads of tokens to zapper contract ")
    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_to_mint_token_0 = 100 * (10 ** token_0_decimals)
    ## Mint token_0 to user_2
    await random_signer.send_transaction(random_account, token_0.contract_address, 'mint', [zapper_out.contract_address, *uint(amount_to_mint_token_0)])
    
    execution_info = await token_1.decimals().call()
    token_1_decimals = execution_info.result.decimals
    amount_to_mint_token_1 = 150 * (10 ** token_1_decimals)
    ## Mint token_1 to user_2
    await random_signer.send_transaction(random_account, token_1.contract_address, 'mint', [zapper_out.contract_address, *uint(amount_to_mint_token_1)])
    
    
    execution_info = await token_2.decimals().call()
    token_2_decimals = execution_info.result.decimals
    amount_to_mint_token_2 = 80 * (10 ** token_2_decimals)
    ## Mint token_2 to user_2
    await random_signer.send_transaction(random_account, token_2.contract_address, 'mint', [zapper_out.contract_address, *uint(amount_to_mint_token_2)])
    
    execution_info = await deployer_signer.send_transaction(deployer_account, zapper_out.contract_address, 'withdraw_tokens', [
        3,
        token_0.contract_address, 
        token_1.contract_address,
        token_2.contract_address
        
    ])
    
    execution_info = await token_0.balanceOf(deployer_account.contract_address).call()
    deployer_token0_balance = execution_info.result.balance[0]
    print(f"{deployer_token0_balance}")
    
    execution_info = await token_1.balanceOf(deployer_account.contract_address).call()
    deployer_token1_balance = execution_info.result.balance[0]
    print(f"{deployer_token1_balance}")
    
    execution_info = await token_2.balanceOf(deployer_account.contract_address).call()
    deployer_token2_balance = execution_info.result.balance[0]
    print(f"{deployer_token2_balance}")
    
    assert deployer_token0_balance == amount_to_mint_token_0
    assert deployer_token1_balance == amount_to_mint_token_1
    assert deployer_token2_balance == amount_to_mint_token_2
    
 