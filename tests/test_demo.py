from secrets import token_urlsafe
import pytest
import asyncio
import math


def uint(a):
    return(a, 0)

# test for zapIn with one of the toen from pair.
@pytest.mark.asyncio
async def test_zap_out_to_pair_token(deployer,starknet,zapper, router, pair, token_0, token_1, user_1,user_2, random_acc):
    user_1_signer, user_1_account = user_1

    execution_info = await user_1_signer.send_transaction(user_1_account, zapper.contract_address, 'calculate_swap_in_amount', [
        *uint(123456789),
        *uint(123),
        
    ])
    
    token0_rec = execution_info.result.response[0]
    token1_rec = execution_info.result.response[2]
    resp = execution_info.result.response
    print(f"{token0_rec}")
    print(f"{token1_rec}")
    print(f"{resp}")
    
    assert 1==0