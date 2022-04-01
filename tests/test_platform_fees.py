from secrets import token_urlsafe
import pytest
import asyncio
import math


def uint(a):
    return(a, 0)

@pytest.mark.asyncio
async def test_platform_fees_zap_in(deployer,starknet,zapper, router, pair, token_0, token_1, user_1,user_2, random_acc):

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
        300
    ])
    
    execution_info = await zapper.goodwill().call()
    goodwill = execution_info.result.goodwill
    
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
    

@pytest.mark.asyncio
async def test_platform_fees_zap_out(deployer,starknet,zapper_out, router, pair, token_0, token_1, user_1,user_2, random_acc):

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
    
    
    print("Adding initial liqidity to receieve lp tokens")
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
    
    lp_tokens_rec = execution_info.result.response[4]

    print("Updating fees to 3%")
    execution_info = await deployer_signer.send_transaction(deployer_account, zapper_out.contract_address, 'update_goodwill', [
        300
    ])
    
    execution_info = await zapper_out.goodwill().call()
    goodwill = execution_info.result.goodwill
    
    assert goodwill == 300
    
    
    # zap_out_amount = lp_tokens_rec / 2
    zap_out_amount = 200000000000000000
    
    execution_info = await router.sort_tokens(token_0.contract_address,token_1.contract_address).call()
    token_A = execution_info.result.token0
    token_B = execution_info.result.token1
    
    print(f"{token_0.contract_address}")
    print(f"{token_1.contract_address}")
    print(f"{token_A}")
    print(f"{token_B}")

    print("Approve required tokens to be spent by zapper")
    await user_2_signer.send_transaction(user_2_account, pair.contract_address, 'approve', [zapper_out.contract_address, *uint(zap_out_amount)])

    print("Zapping out")
    execution_info = await user_2_signer.send_transaction(user_2_account, zapper_out.contract_address, 'zap_out', [
        token_0.contract_address, 
        pair.contract_address, 
        *uint(zap_out_amount), 
        *uint(0), 
        2, 
        token_A, 
        token_0.contract_address, 
        2,
        token_B, 
        token_0.contract_address       
        
    ])
    
    token0_rec = execution_info.result.response[0]
    print(f"{token0_rec}")
     
        
    execution_info = await token_0.balanceOf(zapper_out.contract_address).call()
    zapper_token0_balance = execution_info.result.balance[0]
    print(f"{zapper_token0_balance}")
    
    expected_fees_paid = (token0_rec*3)/97

    
    # tokens-rec are transfered to user after reducing the fees
    assert float(zapper_token0_balance) == pytest.approx(expected_fees_paid)
    
