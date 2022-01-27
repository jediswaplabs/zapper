from secrets import token_urlsafe
import pytest
import asyncio
import math


def uint(a):
    return(a, 0)

@pytest.mark.asyncio
async def test_platform_fees(deployer,starknet,zapper, router, pair, token_0, token_1, user_1,user_2, random_acc):

    user_1_signer, user_1_account = user_1
    user_2_signer, user_2_account = user_2
    random_signer, random_account = random_acc
    deployer_signer, deployer_account = deployer
    
    print("\nMint loads of tokens to user_2 to add initial liquidity")
    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_to_mint_token_0 = 60 * (10 ** token_0_decimals)
    ## Mint token_0 to user_2
    await random_signer.send_transaction(random_account, token_0.contract_address, 'mint', [user_2_account.contract_address, *uint(amount_to_mint_token_0)])
    
    execution_info = await token_1.decimals().call()
    token_1_decimals = execution_info.result.decimals
    amount_to_mint_token_1 = 40 * (10 ** token_1_decimals)
    ## Mint token_1 to user_2
    await random_signer.send_transaction(random_account, token_1.contract_address, 'mint', [user_2_account.contract_address, *uint(amount_to_mint_token_1)])
    
    
    print("Adding initial liqidity to allow swapping in pool")
    amount_token_0 = 60 * (10 ** token_0_decimals)
    amount_token_1 = 40 * (10 ** token_0_decimals)
    # amount_token_1 = amount_token_0
    print("Approve required tokens to be spent by router")
    await user_2_signer.send_transaction(user_2_account, token_0.contract_address, 'approve', [router.contract_address, *uint(amount_token_0)])
    await user_2_signer.send_transaction(user_2_account, token_1.contract_address, 'approve', [router.contract_address, *uint(amount_token_1)])
    
    execution_info = await user_2_signer.send_transaction(user_2_account, router.contract_address, 'add_liquidity', [
        token_0.contract_address, 
        token_1.contract_address, 
        *uint(amount_token_0), 
        *uint(amount_token_1), 
        *uint(0), 
        *uint(0), 
        user_2_account.contract_address, 
        0
    ])

    print("Updating fees to 3%")
    execution_info = await deployer_signer.send_transaction(deployer_account, zapper.contract_address, 'update_goodwill', [
        *uint(300)
    ])
    
    execution_info = await zapper.goodwill().call()
    goodwill = execution_info.result.goodwill[0]
    
    assert goodwill == 300
    
    print("\nMint tokens to user_1 ")
    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_to_mint_token_0 = 10 * (10 ** token_0_decimals)
    ## Mint token_0 to user_2
    await random_signer.send_transaction(random_account, token_0.contract_address, 'mint', [user_1_account.contract_address, *uint(amount_to_mint_token_0)])
    
    
    zap_in_amount = 10 * (10 ** token_0_decimals)

    print("Approve required tokens to be spent by zapper")
    await user_1_signer.send_transaction(user_1_account, token_0.contract_address, 'approve', [zapper.contract_address, *uint(zap_in_amount)])

    print("Zapping in")
    execution_info = await user_1_signer.send_transaction(user_1_account, zapper.contract_address, 'zap_in', [
        token_0.contract_address, 
        pair.contract_address, 
        *uint(zap_in_amount), 
        *uint(0), 
        2, 
        token_0.contract_address, 
        token_1.contract_address,  
        1
    ])
    
    lp_bought = execution_info.result.response[0]
    print(f"{lp_bought}")
    
    execution_info = await pair.balanceOf(user_1_account.contract_address).call()
    user_1_pair_balance = execution_info.result.balance[0]
    print(f"{user_1_pair_balance}")
    
    # all lp tokens are transfered to user_1
    assert lp_bought == user_1_pair_balance
    
    execution_info = await token_0.balanceOf(zapper.contract_address).call()
    zapper_token0_balance = execution_info.result.balance[0]
    print(f"{zapper_token0_balance}")
    
    execution_info = await token_1.balanceOf(zapper.contract_address).call()
    zapper_token1_balance = execution_info.result.balance[0]
    print(f"{zapper_token1_balance}")
    
    # Residual is transfered back to the user(except the fees)
    assert zapper_token0_balance == (zap_in_amount*300)/10000
    assert zapper_token1_balance == 0
    
