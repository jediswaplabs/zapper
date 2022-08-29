%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

@contract_interface
namespace IZapper:
    func owner() -> (owner: felt):
    end

    func router() -> (router: felt):
    end
end

@contract_interface
namespace IZapperOut:
    func owner() -> (owner: felt):
    end

    func router() -> (router: felt):
    end
end

@external
func __setup__():
    alloc_locals

    tempvar deployer_address = 1

    %{ 
        context.deployer_address = ids.deployer_address
        context.declared_pair_class_hash = declare("./contracts/test/AMM/Pair.cairo").class_hash
        context.factory_address = deploy_contract("./contracts/test/AMM/Factory.cairo", [context.declared_pair_class_hash, context.deployer_address]).contract_address
        context.router_address = deploy_contract("./contracts/test/AMM/Router.cairo", [context.factory_address]).contract_address
    %}
    
    return ()
end


@external
func test_zapper{syscall_ptr: felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    tempvar router_address
    tempvar deployer_address
    tempvar contract_address

    %{ 
        ids.router_address = context.router_address
        ids.deployer_address = context.deployer_address        
        context.contract_address = deploy_contract("./contracts/Zapper.cairo", [context.router_address, context.deployer_address]).contract_address
        ids.contract_address = context.contract_address
    %}
    
    let (res) = IZapper.router(contract_address=contract_address)
    assert res = router_address
    
    let (res) = IZapper.owner(contract_address=contract_address)
    assert res = deployer_address
    
    return ()
end


@external
func test_zapper_out{syscall_ptr: felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    tempvar router_address
    tempvar deployer_address
    tempvar contract_address

    %{ 
        ids.router_address = context.router_address
        ids.deployer_address = context.deployer_address        
        context.contract_address = deploy_contract("./contracts/ZapperOut.cairo", [context.router_address, context.deployer_address]).contract_address 
        ids.contract_address = context.contract_address
    %}
    
    let (res) = IZapperOut.router(contract_address=contract_address)
    assert res = router_address
    
    let (res) = IZapperOut.owner(contract_address=contract_address)
    assert res = deployer_address
    
    return ()
end