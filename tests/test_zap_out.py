from secrets import token_urlsafe
import pytest
import asyncio
import math


def uint(a):
    return(a, 0)

# test for zapIn with one of the token from pair.
@pytest.mark.asyncio
async def test_zap_out_to_pair_token(deployer,starknet,zapper_out, router, pair, token_0, token_1, user_1,user_2, random_acc):
    user_1_signer, user_1_account = user_1
    user_2_signer, user_2_account = user_2
    random_signer, random_account = random_acc
    deployer_signer, deployer_account = deployer
    
    print("\nMint loads of tokens to user_1 to add initial liquidity")
    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_to_mint_token_0 = 60 * (10 ** token_0_decimals)
    ## Mint token_0 to user_1
    await random_signer.send_transaction(random_account, token_0.contract_address, 'mint', [user_1_account.contract_address, *uint(amount_to_mint_token_0)])
    
    execution_info = await token_1.decimals().call()
    token_1_decimals = execution_info.result.decimals
    amount_to_mint_token_1 = 40 * (10 ** token_1_decimals)
    ## Mint token_1 to user_1
    await random_signer.send_transaction(random_account, token_1.contract_address, 'mint', [user_1_account.contract_address, *uint(amount_to_mint_token_1)])
    
    
    print("Adding liqidity to receieve lp token")
    amount_token_0 = 60 * (10 ** token_0_decimals)
    amount_token_1 = 40 * (10 ** token_0_decimals)
    print("Approve required tokens to be spent by router")
    await user_1_signer.send_transaction(user_1_account, token_0.contract_address, 'approve', [router.contract_address, *uint(amount_token_0)])
    await user_1_signer.send_transaction(user_1_account, token_1.contract_address, 'approve', [router.contract_address, *uint(amount_token_1)])
    
    execution_info = await user_1_signer.send_transaction(user_1_account, router.contract_address, 'add_liquidity', [
        token_0.contract_address, 
        token_1.contract_address, 
        *uint(amount_token_0), 
        *uint(amount_token_1), 
        *uint(0), 
        *uint(0), 
        user_1_account.contract_address, 
        0
    ])
    
    lp_tokens_rec = execution_info.result.response[4]
    print(f"{lp_tokens_rec}")

    # zap_out_amount = int(lp_tokens_rec) / 2
    zap_out_amount = 20000000000000000000
    
    execution_info = await token_0.balanceOf(user_1_account.contract_address).call()
    user1_initial_token0_balance = execution_info.result.balance[0]
    
    execution_info = await router.sort_tokens(token_0.contract_address,token_1.contract_address).call()
    token_A = execution_info.result.token0
    token_B = execution_info.result.token1
    
    print(f"{token_0.contract_address}")
    print(f"{token_1.contract_address}")
    print(f"{token_A}")
    print(f"{token_B}")
    
    # if 
    

    print("Approve required tokens to be spent by zapper")
    await user_1_signer.send_transaction(user_1_account, pair.contract_address, 'approve', [zapper_out.contract_address, *uint(zap_out_amount)])

    print("Zapping out")
    execution_info = await user_1_signer.send_transaction(user_1_account, zapper_out.contract_address, 'zap_out', [
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
    
    execution_info = await pair.balanceOf(user_1_account.contract_address).call()
    user_1_pair_balance = execution_info.result.balance[0]
    print(f"{user_1_pair_balance}")
    
    assert user_1_pair_balance == lp_tokens_rec - zap_out_amount
    
    execution_info = await token_0.balanceOf(user_1_account.contract_address).call()
    user1_final_token0_balance = execution_info.result.balance[0]
    print(f"{user1_final_token0_balance}")
    
    assert user1_final_token0_balance == user1_initial_token0_balance + token0_rec
    
    
@pytest.mark.asyncio
async def test_zap_out_to_other_token(deployer,starknet,zapper_out, router, pair,other_pair,third_pair, token_0, token_1,token_2, user_1,user_2, random_acc):
    user_1_signer, user_1_account = user_1
    user_2_signer, user_2_account = user_2
    random_signer, random_account = random_acc
    deployer_signer, deployer_account = deployer
    
    print("\nMint loads of tokens to user_2 to add initial liquidity")
    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_to_mint_token_0 = 60 * (10 ** token_0_decimals)
    ## Mint token_0 to user_1
    await random_signer.send_transaction(random_account, token_0.contract_address, 'mint', [user_2_account.contract_address, *uint(amount_to_mint_token_0)])
    
    execution_info = await token_1.decimals().call()
    token_1_decimals = execution_info.result.decimals
    amount_to_mint_token_1 = 40 * (10 ** token_1_decimals)
    ## Mint token_1 to user_1
    await random_signer.send_transaction(random_account, token_1.contract_address, 'mint', [user_2_account.contract_address, *uint(amount_to_mint_token_1)])
    
    execution_info = await token_2.decimals().call()
    token_2_decimals = execution_info.result.decimals
    amount_to_mint_token_2 = 100 * (10 ** token_2_decimals)
    ## Mint token_1 to user_1
    await random_signer.send_transaction(random_account, token_2.contract_address, 'mint', [user_2_account.contract_address, *uint(amount_to_mint_token_2)])
    
    
    print("Adding liqidity to enable swap")
    amount_token_0 = 60 * (10 ** token_0_decimals)
    amount_token_2 = 40 * (10 ** token_2_decimals)
    print("Approve required tokens to be spent by router")
    await user_2_signer.send_transaction(user_2_account, token_0.contract_address, 'approve', [router.contract_address, *uint(amount_token_0)])
    await user_2_signer.send_transaction(user_2_account, token_2.contract_address, 'approve', [router.contract_address, *uint(amount_token_2)])
    
    execution_info = await user_2_signer.send_transaction(user_2_account, router.contract_address, 'add_liquidity', [
        token_0.contract_address, 
        token_2.contract_address, 
        *uint(amount_token_0), 
        *uint(amount_token_2), 
        *uint(0), 
        *uint(0), 
        user_2_account.contract_address, 
        0
    ])
    
    print("Adding liqidity to enable swap")
    amount_token_1 = 40 * (10 ** token_1_decimals)
    amount_token_2 = 60 * (10 ** token_2_decimals)

    print("Approve required tokens to be spent by router")
    await user_2_signer.send_transaction(user_2_account, token_1.contract_address, 'approve', [router.contract_address, *uint(amount_token_1)])
    await user_2_signer.send_transaction(user_2_account, token_2.contract_address, 'approve', [router.contract_address, *uint(amount_token_2)])
    
    execution_info = await user_2_signer.send_transaction(user_2_account, router.contract_address, 'add_liquidity', [
        token_1.contract_address, 
        token_2.contract_address, 
        *uint(amount_token_1), 
        *uint(amount_token_2), 
        *uint(0), 
        *uint(0), 
        user_2_account.contract_address, 
        0
    ])
    
    print("\nMint loads of tokens to user_1 to receieve lp tokens")
    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_to_mint_token_0 = 6 * (10 ** token_0_decimals)
    ## Mint token_0 to user_1
    await random_signer.send_transaction(random_account, token_0.contract_address, 'mint', [user_1_account.contract_address, *uint(amount_to_mint_token_0)])
    
    execution_info = await token_1.decimals().call()
    token_1_decimals = execution_info.result.decimals
    amount_to_mint_token_1 = 4 * (10 ** token_1_decimals)
    ## Mint token_1 to user_1
    await random_signer.send_transaction(random_account, token_1.contract_address, 'mint', [user_1_account.contract_address, *uint(amount_to_mint_token_1)])
    
    
    print("Adding liqidity to receieve lp token")
    amount_token_0 = 6 * (10 ** token_0_decimals)
    amount_token_1 = 4 * (10 ** token_0_decimals)
    print("Approve required tokens to be spent by router")
    await user_1_signer.send_transaction(user_1_account, token_0.contract_address, 'approve', [router.contract_address, *uint(amount_token_0)])
    await user_1_signer.send_transaction(user_1_account, token_1.contract_address, 'approve', [router.contract_address, *uint(amount_token_1)])
    
    execution_info = await user_1_signer.send_transaction(user_1_account, router.contract_address, 'add_liquidity', [
        token_0.contract_address, 
        token_1.contract_address, 
        *uint(amount_token_0), 
        *uint(amount_token_1), 
        *uint(0), 
        *uint(0), 
        user_1_account.contract_address, 
        0
    ])
    
    lp_tokens_rec = execution_info.result.response[4]
    print(f"{lp_tokens_rec}")
    # zap_out_amount = lp_tokens_rec / 2
    zap_out_amount = 1000000000000000000
    
    execution_info = await token_2.balanceOf(user_1_account.contract_address).call()
    user1_initial_token2_balance = execution_info.result.balance[0]
    
    execution_info = await router.sort_tokens(token_0.contract_address,token_1.contract_address).call()
    token_A = execution_info.result.token0
    token_B = execution_info.result.token1
    
    print(f"{token_0.contract_address}")
    print(f"{token_1.contract_address}")
    print(f"{token_A}")
    print(f"{token_B}")

    print("Approve required tokens to be spent by zapper")
    await user_1_signer.send_transaction(user_1_account, pair.contract_address, 'approve', [zapper_out.contract_address, *uint(zap_out_amount)])

    print("Zapping out")
    execution_info = await user_1_signer.send_transaction(user_1_account, zapper_out.contract_address, 'zap_out', [
        token_2.contract_address, 
        pair.contract_address, 
        *uint(zap_out_amount), 
        *uint(0), 
        2,
        token_A, 
        token_2.contract_address,  
        2, 
        token_B, 
        token_2.contract_address,  
        
    ])
    
    
    token2_rec = execution_info.result.response[0]
    print(f"{token2_rec}")
    
    execution_info = await pair.balanceOf(user_1_account.contract_address).call()
    user_1_pair_balance = execution_info.result.balance[0]
    print(f"{user_1_pair_balance}")
    
    assert user_1_pair_balance == lp_tokens_rec - zap_out_amount
    
    execution_info = await token_2.balanceOf(user_1_account.contract_address).call()
    user1_final_token2_balance = execution_info.result.balance[0]
    print(f"{user1_final_token2_balance}")
    
    assert user1_final_token2_balance == user1_initial_token2_balance + token2_rec
    
   