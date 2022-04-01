import pytest
import asyncio



@pytest.mark.asyncio
async def test_zapper(zapper, router, deployer):
    
    execution_info = await zapper.router().call()
    assert execution_info.result.router == router.contract_address
    
    deployer_signer, deployer_account = deployer
    execution_info = await zapper.owner().call()
    assert execution_info.result.owner == deployer_account.contract_address


@pytest.mark.asyncio
async def test_zapper_out( zapper_out, router, deployer):
    
    execution_info = await zapper_out.router().call()
    assert execution_info.result.router == router.contract_address
    
    deployer_signer, deployer_account = deployer
    execution_info = await zapper_out.owner().call()
    assert execution_info.result.owner == deployer_account.contract_address
