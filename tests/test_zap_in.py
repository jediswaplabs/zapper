from secrets import token_urlsafe
import pytest
import asyncio
import math


def uint(a):
    return(a, 0)

# test for zapIn with one of the toen from pair.
@pytest.mark.asyncio
async def test_zap_in_from_same_token(deployer,starknet,zapper, router, pair, token_0, token_1, user_1,user_2, random_acc):
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
    
    
    lp_tokens = execution_info.result.response[0]
    print(f"{lp_tokens}")
    
    execution_info = await pair.balanceOf(user_1_account.contract_address).call()
    user_1_pair_balance = execution_info.result.balance[0]
    print(f"{user_1_pair_balance}")
    
    assert lp_tokens == user_1_pair_balance
    
    execution_info = await token_0.balanceOf(zapper.contract_address).call()
    zapper_token0_balance = execution_info.result.balance[0]
    print(f"{zapper_token0_balance}")
    
    execution_info = await token_1.balanceOf(zapper.contract_address).call()
    zapper_token1_balance = execution_info.result.balance[0]
    print(f"{zapper_token1_balance}")
    
    # Residual is transfered back to the user
    assert zapper_token0_balance == 0
    assert zapper_token1_balance == 0
    
    # execution_info = await router.sort_tokens(token_1.contract_address, token_2.contract_address).call()
    # tokenA = execution_info.result.token0
    # tokenB = execution_info.result.token1
    
    # execution_info = await pair.get_reserves().call()
    # resA = execution_info.result.reserve0
    # resB = execution_info.result.reserve1
    
    # if token_0 == tokenA:
    #     res = resA
    # else :
    #     res = resB

    # amount_to_swap = ((math.sqrt(resA*3988000 + zap_in_amount*3988009)) - (zap_in_amount*1997))/1994
    # execution_info = await router.get_amounts_out(amount_to_swap,2,token_0.contract_address,token_1.contract_address).call()
    # path_len = execution_info.result.response[0]
    # amounts = execution_info.result.response[1:]
    
    # print(f"{amounts}")
    
    
    # expected_token1_receieved = amounts[path_len-1]
    # token0_left = zap_in_amount - expected_token1_receieved
    
    # ******** now if I even find how much lp token will received on adding tokens it will be calculated for current pool state not 
    # the updated one after swap *******************
    
    
@pytest.mark.asyncio
async def test_zap_in_from_other_token(deployer,starknet,zapper, router, pair,other_pair, token_0, token_1,token_2, user_1,user_2, random_acc):
    user_1_signer, user_1_account = user_1
    user_2_signer, user_2_account = user_2
    random_signer, random_account = random_acc
    deployer_signer, deployer_account = deployer
    
    print("\nMint loads of tokens to user_2 to add initial liquidity")
    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_to_mint_token_0 = 1000 * (10 ** token_0_decimals)
    ## Mint token_0 to user_2
    await random_signer.send_transaction(random_account, token_0.contract_address, 'mint', [user_2_account.contract_address, *uint(amount_to_mint_token_0)])
    
    execution_info = await token_1.decimals().call()
    token_1_decimals = execution_info.result.decimals
    amount_to_mint_token_1 = 1500 * (10 ** token_1_decimals)
    ## Mint token_1 to user_2
    await random_signer.send_transaction(random_account, token_1.contract_address, 'mint', [user_2_account.contract_address, *uint(amount_to_mint_token_1)])
    
    execution_info = await token_2.decimals().call()
    token_2_decimals = execution_info.result.decimals
    amount_to_mint_token_2 = 1000 * (10 ** token_2_decimals)
    ## Mint token_1 to user_2
    await random_signer.send_transaction(random_account, token_2.contract_address, 'mint', [user_2_account.contract_address, *uint(amount_to_mint_token_2)])
    
    
    print("Adding initial liqidity to allow swapping in pool")
    amount_token_0 = 600 * (10 ** token_0_decimals)
    amount_token_1 = 400 * (10 ** token_1_decimals)
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
    
    amount_token_1 = 600 * (10 ** token_1_decimals)
    amount_token_2 = 400 * (10 ** token_2_decimals)
    # amount_token_1 = amount_token_0
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
    

    print("\nMint token_0 to user_1 for zap in")
    execution_info = await token_0.decimals().call()
    token_0_decimals = execution_info.result.decimals
    amount_to_mint_token_0 = 40 * (10 ** token_0_decimals)
    ## Mint token_0 to user_2
    await random_signer.send_transaction(random_account, token_0.contract_address, 'mint', [user_1_account.contract_address, *uint(amount_to_mint_token_0)])
    
    execution_info = await token_0.balanceOf(user_1_account.contract_address).call()
    user_1_pair_balance = execution_info.result.balance[0]
    print(f"{user_1_pair_balance}")
    zap_in_amount = amount_to_mint_token_0
    
    await user_1_signer.send_transaction(user_1_account, token_0.contract_address, 'approve', [router.contract_address, *uint(amount_to_mint_token_0)])
    
    # execution_info = await router.get_amounts_out(amount_to_mint_token_2,2,token_2.contract_address,token_1.contract_address).call()

    # path_len = execution_info.result.path_len
    # amounts = execution_info.result.amounts
    
    # print(f"{path_len}, {amounts}")



    # execution_info = await user_1_signer.send_transaction(user_1_account, router.contract_address, 'swap_exact_tokens_for_tokens', [
    #     *uint(amount_to_mint_token_2), 
    #     *uint(0), 
    #     2, 
    #     token_1.contract_address, 
    #     token_2.contract_address, 
    #     user_1_account.contract_address, 
    #     0
    # ])
    
    # path_len = execution_info.result.response[0]
    # amounts = execution_info.result.response[1:]

    # amountOUT = amounts[path_len -1]
    # print(f"{path_len}, {amounts}, {amountOUT}")

    
    
    # execution_info = await token_1.balanceOf(user_1_account.contract_address).call()
    # user_1_pair_balance = execution_info.result.balance[0]
    # print(f"{user_1_pair_balance}")
    # execution_info = await token_2.balanceOf(user_1_account.contract_address).call()
    # user_1_pair_balance = execution_info.result.balance[0]
    # print(f"{user_1_pair_balance}")
    
    # assert 1==0

    print("Approve required tokens to be spent by zapper")
    await user_1_signer.send_transaction(user_1_account, token_0.contract_address, 'approve', [zapper.contract_address, *uint(zap_in_amount)])

    print("Zapping in")
    execution_info = await user_1_signer.send_transaction(user_1_account, zapper.contract_address, 'zap_in', [
        token_0.contract_address, 
        other_pair.contract_address, 
        *uint(zap_in_amount), 
        *uint(0), 
        2, 
        token_0.contract_address, 
        token_1.contract_address,  
        1
    ])
    
    
    lp_tokens = execution_info.result.response[0]
    print(f"{lp_tokens}")
    
    execution_info = await other_pair.balanceOf(user_1_account.contract_address).call()
    user_1_pair_balance = execution_info.result.balance[0]
    print(f"{user_1_pair_balance}")
    
    assert lp_tokens == user_1_pair_balance
    
    execution_info = await token_1.balanceOf(zapper.contract_address).call()
    zapper_token1_balance = execution_info.result.balance[0]
    print(f"{zapper_token1_balance}")
    
    execution_info = await token_2.balanceOf(zapper.contract_address).call()
    zapper_token2_balance = execution_info.result.balance[0]
    print(f"{zapper_token2_balance}")
    
    # Residual is transfered back to the user
    assert zapper_token1_balance == 0
    assert zapper_token2_balance == 0
  