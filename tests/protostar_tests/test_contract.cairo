%lang starknet


@contract_interface
namespace StorageContract:
    func increase_balance(amount : felt):
    end

    func get_balance() -> (res : felt):
    end
end


@external
func test_increase_balance{syscall_ptr: felt*, range_check_ptr}():
    alloc_locals

    local contract_address: felt
    %{ ids.contract_address = deploy_contract("./contracts/contract.cairo").contract_address %}

    let (res) = StorageContract.get_balance(contract_address=contract_address)
    assert res = 0

    # Invoke increase_balance() twice
    StorageContract.increase_balance(contract_address=contract_address, amount=10)
    StorageContract.increase_balance(contract_address=contract_address, amount=20)
    
    let (res) = StorageContract.get_balance(contract_address=contract_address)
    assert res = 30
    return ()
end