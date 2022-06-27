%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.math import assert_le, assert_not_zero, assert_not_equal
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import (Uint256, uint256_eq, uint256_le, uint256_check, uint256_lt, uint256_sqrt, 
    uint256_add, uint256_sub, uint256_mul, uint256_unsigned_div_rem)
from starkware.cairo.common.alloc import alloc
from contracts.utils.math import uint256_checked_add, uint256_checked_sub_lt, uint256_checked_sub_le, uint256_checked_mul, uint256_felt_checked_mul


#
# Interfaces
#
@contract_interface
namespace IERC20:

    func balanceOf(account: felt) -> (balance: Uint256):
    end

    func transferFrom(
            sender: felt, 
            recipient: felt, 
            amount: Uint256
        ) -> (success: felt):
    end

    func transfer(recipient: felt, amount: Uint256) -> (success: felt):
    end

    func approve(spender: felt, amount: Uint256) -> (success: felt):
    end


end

@contract_interface
namespace IPair:
    
    func get_reserves() -> (reserve0: Uint256, reserve1: Uint256, block_timestamp_last: felt):
    end

    func token0() -> (address: felt):
    end

    func token1() -> (address: felt):
    end

end

@contract_interface
namespace IFactory:
    func get_pair(token0: felt, token1: felt) -> (pair: felt):
    end
end


@contract_interface
namespace IRouter:

    func factory() -> (address: felt):
    end


    func add_liquidity(tokenA: felt, tokenB: felt, amountADesired: Uint256, amountBDesired: Uint256,
    amountAMin: Uint256, amountBMin: Uint256, to: felt, deadline: felt) -> (amountA: Uint256, amountB: Uint256, liquidity: Uint256):
    end

    func swap_exact_tokens_for_tokens(amountIn: Uint256, amountOutMin: Uint256, path_len: felt, path: felt*, 
    to: felt, deadline: felt) -> (amounts_len: felt, amounts: Uint256*):
    end
end


#
# Storage
#

# @dev Router contract address
@storage_var
func _jedi_router() -> (address: felt):
end

# @dev factory contract address
@storage_var
func _jedi_factory() -> (address: felt):
end

# @dev goodwill percentage in thousandths of a %. i.e. 500 = 0.5%
@storage_var
func _goodwill() -> (res: felt):
end

# @dev deadline for AMM function
@storage_var
func _deadline() -> (res: felt):
end


# @notice An event emitted whenever zap in.
@event
func Zapped_in(sender: felt, from_token: felt, pool_address: felt, tokens_rec: Uint256):
end

#
# Storage Ownable
#

# @dev Address of the owner of the contract
@storage_var
func _owner() -> (address: felt):
end

# @dev Address of the future owner of the contract
@storage_var
func _future_owner() -> (address: felt):
end

# An event emitted whenever initiate_ownership_transfer() is called.
@event
func owner_change_initiated(current_owner: felt, future_owner: felt):
end

# An event emitted whenever accept_ownership() is called.
@event
func owner_change_completed(current_owner: felt, future_owner: felt):
end


#
# Constructor
#

# @notice Contract constructor
# @param router Address of router contract
# @param initial_owner Owner of this zapper contract 
@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        router:felt,
        initial_owner:felt
    ):
    # get_caller_address() returns '0' in the constructor;
    # therefore, initial_owner parameter is included
    assert_not_zero(router)
    assert_not_zero(initial_owner)

    let (factory: felt) = IRouter.factory(contract_address = router)
    _jedi_factory.write(factory)
    _jedi_router.write(router)
    _goodwill.write(0)
    _owner.write(initial_owner)
    _deadline.write(999999999999999999999999)  # set to largest number possible 
    return ()
end

#
# Getters 
#

# @notice Get contract owner address
# @return owner
@view
func owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (owner: felt):
    let (owner) = _owner.read()
    return (owner)
end


# @notice Get Router address
# @return router
@view
func router{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (router: felt):
    let (router) = _jedi_router.read()
    return (router)
end

# @notice Get goodwill percentage
# @return goodwill
@view
func goodwill{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (goodwill: felt):
    let (goodwill) = _goodwill.read()
    return (goodwill)
end


#
# Setters 
#

# @notice Update goodwill to `new_goodwill`
# @dev Only owner can change 
# @param new_goodwill value in thousandths of a %. i.e. 500 = 0.5%
@external
func update_goodwill{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }( new_goodwill:felt):
    alloc_locals
    _only_owner()

    _goodwill.write(new_goodwill)
    return ()
end

# @notice Update router to `new_router`
# @dev Only owner can change 
# @param new_router the address of the new router
@external
func update_router{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }( new_router:felt):
    alloc_locals
    _only_owner()

    _jedi_router.write(new_router)
    let (factory: felt) = IRouter.factory(contract_address = new_router)
    _jedi_factory.write(factory)
    return ()
end


#
# Setters Ownable
#

# @notice Change ownership to `future_owner`
# @dev Only owner can change. Needs to be accepted by future_owner using accept_ownership
# @param future_owner Address of new owner
@external
func initiate_ownership_transfer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(future_owner: felt) -> (future_owner: felt):
    _only_owner()
    let (current_owner) = _owner.read()
    with_attr error_message("Zapper::initiate_ownership_transfer::New owner can not be zero"):
        assert_not_zero(future_owner)
    end
    _future_owner.write(future_owner)
    owner_change_initiated.emit(current_owner=current_owner, future_owner=future_owner)
    return (future_owner=future_owner)
end

# @notice Change ownership to future_owner
# @dev Only future_owner can accept. Needs to be initiated via initiate_ownership_transfer
@external
func accept_ownership{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (current_owner) = _owner.read()
    let (future_owner) = _future_owner.read()
    let (caller) = get_caller_address()
    with_attr error_message("Zapper::accept_ownership::Only future owner can accept"):
        assert future_owner = caller
    end
    _owner.write(future_owner)
    owner_change_completed.emit(current_owner=current_owner, future_owner=future_owner)
    return ()
end


#
# Internals Ownable
#

func _only_owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (owner) = _owner.read()
    let (caller) = get_caller_address()
    with_attr error_message("Zapper::_only_owner::Caller must be owner"):
        assert owner = caller
    end
    return ()
end




#
# Externals
#

# @notice Zap in token to receieve liquidity tokens
# @dev `caller` should have already given the router an allowance of at least amount on from_token
# @param from_token_address Address of from_token
# @param pair_address Address of pair
# @param amount The amount of from_token to add as liquidity
# @param min_pool_token Bounds the extent to which liquidity tokens receieved before the transaction reverts.
# @param path_len The length of route to swap from_token to one of pair_token
# @param path The route to swap from_token to one of pair_token
# @param transfer_residual Should transfer the residual left after adding liquidity back to user ; 0-> False : 1-> true
# @return lp_bought The amount of liquidity tokens receieved
@external
func zap_in{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(from_token_address: felt, pair_address: felt, amount: Uint256, min_pool_token: Uint256,
    path_len: felt, path: felt*, transfer_residual: felt) -> (lp_bought: Uint256):
    alloc_locals
    assert_not_zero(pair_address)
    assert_not_zero(from_token_address)
    uint256_check(amount)
    let (is_amount_equal_to_0) =  uint256_eq(amount, Uint256(0, 0))
    assert is_amount_equal_to_0 = 0

    let (sender) = get_caller_address()
    let (contract_address) = get_contract_address()

    IERC20.transferFrom(contract_address=from_token_address, sender=sender, recipient=contract_address, amount=amount)

    let (goodwill:felt) = _goodwill.read()
    let (goodwill_amount:Uint256)  = uint256_checked_mul(amount, Uint256(goodwill,0))
    let (goodwill_portion:Uint256,_) = uint256_unsigned_div_rem(goodwill_amount,Uint256(10000,0))
    let amount_to_invest:Uint256 = uint256_checked_sub_lt(amount,goodwill_portion)

    let (lp_bought:Uint256) = _perform_zap_in(from_token_address, pair_address, amount_to_invest, path_len, path, transfer_residual)

    let is_lp_bought_less_than_equal_min_pool_token:felt = uint256_le(min_pool_token,lp_bought)
    assert_not_zero(is_lp_bought_less_than_equal_min_pool_token)
    IERC20.transfer(contract_address=pair_address, recipient=sender, amount=lp_bought)

    Zapped_in.emit(sender = sender, from_token = from_token_address, pool_address = pair_address, tokens_rec = lp_bought)

    return (lp_bought)
end

# @notice Withdraw the tokens accumulated in zapper contract because of goodwill tax
# @dev Only owner call this
# @param tokens_len The number of tokens withdrawing
# @param tokens The Array of withdrawing token address
@external
func withdraw_tokens{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }( tokens_len: felt, tokens: felt*):
    alloc_locals
    _only_owner()

    let (owner) = _owner.read()
    let (contract_address) = get_contract_address()
    if tokens_len == 0:
        return ()
    end

    let (amount:Uint256) = IERC20.balanceOf(contract_address = [tokens], account = contract_address)

    IERC20.transfer(contract_address=[tokens], recipient=owner, amount=amount)

    return withdraw_tokens(tokens_len = tokens_len - 1, tokens = &tokens[1])

end


#
# Internals
#


func _perform_zap_in{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(from_token_address: felt, pair_address: felt, amount: Uint256, path_len: felt, 
    path: felt*, transfer_residual: felt) -> (liquidity: Uint256):
    alloc_locals
    local intermediate_amt: Uint256 
    local intermediate_token: felt
    let (token0,token1) = _get_pair_tokens(pair_address)

    if from_token_address == token0 :
        assert intermediate_amt = amount
        intermediate_token = from_token_address
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr

    else:
        if from_token_address == token1 :
            assert intermediate_amt = amount
            intermediate_token = from_token_address
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        else:
            let (temp_amt:Uint256,temp_token:felt) = _fill_quote(from_token_address, pair_address, amount, path_len, path)
            assert intermediate_amt = temp_amt
            intermediate_token = temp_token
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        end
        
    end

    local syscall_ptr: felt* = syscall_ptr
    local pedersen_ptr: HashBuiltin* = pedersen_ptr
    
    let (token0_bought:Uint256, token1_bought:Uint256) = _swap_intermediate(intermediate_token, token0, token1, intermediate_amt)
    
    return _jedi_deposit(token0, token1, token0_bought, token1_bought, transfer_residual)
end

func _jedi_deposit{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(token0: felt,token1: felt,token0_bought: Uint256, token1_bought: Uint256, transfer_residual :felt) -> (liquidity: Uint256):
    alloc_locals
    let router:felt = _jedi_router.read() 

    IERC20.approve(contract_address= token0, spender= router, amount= token0_bought)
    IERC20.approve(contract_address= token1, spender= router, amount= token1_bought)

    let (contract_address) = get_contract_address()
    let (deadline:felt) = _deadline.read()
    let(amountA:Uint256, amountB:Uint256, liquidity:Uint256) = IRouter.add_liquidity(contract_address = router, tokenA = token0,tokenB = token1, amountADesired = token0_bought, amountBDesired = token1_bought, amountAMin = Uint256(1,0), amountBMin = Uint256(1,0), to = contract_address,deadline = deadline )

    let (sender) = get_caller_address()

    if transfer_residual == 1:
        let (is_amountA_less_than_token0_bought) = uint256_lt(amountA,token0_bought)
        if is_amountA_less_than_token0_bought == 1 :
            let amount:Uint256 = uint256_sub(token0_bought,amountA)
            IERC20.transfer(contract_address = token0, recipient = sender, amount = amount)
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        else:
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr

        end

        local syscall_ptr: felt* = syscall_ptr
        local pedersen_ptr: HashBuiltin* = pedersen_ptr

        let (is_amountB_less_than_token1_bought) = uint256_lt(amountB,token1_bought)
        if is_amountB_less_than_token1_bought == 1 :
            let amount:Uint256 = uint256_checked_sub_lt(token1_bought,amountB)
            IERC20.transfer(contract_address = token1, recipient = sender, amount = amount)
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr

        else:
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr

        end
        
     
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr

    end

    
    return (liquidity)
end

func _get_pair_tokens{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(pair_address: felt) -> (token0: felt, token1: felt):
    alloc_locals

    let(token0) = IPair.token0(contract_address= pair_address)
    let(token1) = IPair.token1(contract_address= pair_address)

    return (token0,token1)
end


func _fill_quote{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(from_token_address: felt, pair_address: felt, amount: Uint256, path_len: felt, path: felt*) -> (amount_bought:Uint256, intermediate_token:felt):
    alloc_locals
        
    let(token0, token1) = _get_pair_tokens(pair_address)
    let (contract_address) = get_contract_address()

    let initial_balance0:Uint256 = IERC20.balanceOf(contract_address= token0, account=contract_address)
    let initial_balance1:Uint256 = IERC20.balanceOf(contract_address= token1, account=contract_address)

    let (router) = _jedi_router.read()
    let (deadline) = _deadline.read()

    IERC20.approve(contract_address= from_token_address, spender= router, amount= amount)
    let (amounts_len:felt,amounts) = IRouter.swap_exact_tokens_for_tokens(contract_address = router, amountIn = amount, amountOutMin = Uint256(0, 0), path_len = path_len, path = path, to = contract_address, deadline = deadline ) 
    
    let token_bought:Uint256 = [amounts + amounts_len -2]
    let (is_token_bought_less_than_equal_zero) = uint256_le(token_bought, Uint256(0,0))
    assert is_token_bought_less_than_equal_zero = 0

    let contract_token0_balance:Uint256 = IERC20.balanceOf(contract_address= token0, account=contract_address)
    let final_balance0:Uint256 = uint256_checked_sub_le(contract_token0_balance, initial_balance0)
    
    let contract_token1_balance:Uint256 = IERC20.balanceOf(contract_address= token1, account=contract_address)
    let final_balance1:Uint256 = uint256_checked_sub_le(contract_token1_balance, initial_balance1)

    local amount_bought:Uint256 
    local intermediate_token:felt
    let (is_final_balance1_less_than_equal_final_balance0) = uint256_le(final_balance1, final_balance0)
    if is_final_balance1_less_than_equal_final_balance0 == 1:
        assert amount_bought = final_balance0
        intermediate_token = token0
    
    else:
        assert amount_bought = final_balance1
        intermediate_token = token1
    end
    let (is_amount_bought_equal_to_0) =  uint256_eq(amount_bought, Uint256(0, 0))
    assert_not_equal(is_amount_bought_equal_to_0,1)

    return (amount_bought,intermediate_token)
end

func _swap_intermediate{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(intermediate_token: felt, token0: felt, token1: felt, amount: Uint256) -> (token0_bought: Uint256, token1_bought: Uint256):
    alloc_locals
    let factory:felt = _jedi_factory.read()
    let pair_address:felt = IFactory.get_pair(contract_address = factory, token0= token0, token1= token1)

    let (res0:Uint256, res1:Uint256,_) = IPair.get_reserves(contract_address = pair_address)
    local token1_bought:Uint256
    local token0_bought:Uint256
    local amount_to_swap:Uint256

    let (amount_div_2:Uint256,_) = uint256_unsigned_div_rem(amount,Uint256(2,0))

    if intermediate_token == token0:
        let swap_amount:Uint256 = _calculate_swap_in_amount(res0, amount)
        let (is_swap_amount_less_than_equal_zero:felt) = uint256_le(swap_amount,Uint256(0,0))
        if is_swap_amount_less_than_equal_zero == 1 :
            assert amount_to_swap = amount_div_2
        else:
            assert amount_to_swap = swap_amount
        end
        let tokenB_bought:Uint256 = _token_to_token(intermediate_token,token1,amount_to_swap)
        assert token1_bought = tokenB_bought

        let tokenA_bought:Uint256 = uint256_checked_sub_lt(amount,amount_to_swap)
        assert token0_bought = tokenA_bought
    
    else:
        let swap_amount:Uint256 = _calculate_swap_in_amount(res1, amount)
        let (is_swap_amount_less_than_equal_zero) = uint256_le(swap_amount,Uint256(0,0))
        if is_swap_amount_less_than_equal_zero == 1:
             assert amount_to_swap = amount_div_2
        else:
            assert amount_to_swap = swap_amount
        end
        let tokenA_bought:Uint256 = _token_to_token(intermediate_token,token0,amount_to_swap)
        assert token0_bought = tokenA_bought

        let tokenB_bought:Uint256 = uint256_checked_sub_lt(amount,amount_to_swap)
        assert token1_bought = tokenB_bought
    end
    return (token0_bought,token1_bought)
end

func _token_to_token{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(from_token: felt, to_token: felt, token_to_trade: Uint256) -> (token_bought: Uint256):
    alloc_locals

    if from_token == to_token:
        return (token_to_trade)
    end
    let factory:felt = _jedi_factory.read()
    let router:felt = _jedi_router.read()
    IERC20.approve(contract_address = from_token, spender = router, amount = token_to_trade)

    let pair_address:felt = IFactory.get_pair(contract_address = factory, token0= from_token, token1= to_token)
    assert_not_zero(pair_address)

    let (local path : felt*) = alloc()
    assert [path] = from_token
    assert [path+1] = to_token
    
    let (contract_address) = get_contract_address()
    let (deadline:felt) = _deadline.read()
    let (amounts_len:felt,amounts:Uint256*) = IRouter.swap_exact_tokens_for_tokens(contract_address = router, amountIn = token_to_trade, amountOutMin = Uint256(0, 0), path_len = 2, path = path, to = contract_address, deadline = deadline ) # using a large deadline

    let token_bought:Uint256 = [amounts + Uint256.SIZE]
    let (is_token_bought_less_than_equal_zero) = uint256_le(token_bought, Uint256(0,0))
    assert is_token_bought_less_than_equal_zero = 0
    
    return (token_bought)
end

func _calculate_swap_in_amount{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(reserve_in: Uint256, user_in: Uint256) -> (amount_to_swap: Uint256):
    alloc_locals

    let user_in_mul_3988000:Uint256 = uint256_checked_mul(user_in, Uint256(3988000, 0))
    let reserve_in_mul_3988009:Uint256 = uint256_checked_mul(reserve_in, Uint256(3988009, 0))
    let user_in_mul_3988000_add_reserve_in_mul_3988009:Uint256 = uint256_checked_add(user_in_mul_3988000, reserve_in_mul_3988009)
    let reserve_in_mul_user_in_mul_3988000_add_reserve_in_mul_3988009:Uint256 = uint256_checked_mul(reserve_in, user_in_mul_3988000_add_reserve_in_mul_3988009)
    let sqrt:Uint256 = uint256_sqrt(reserve_in_mul_user_in_mul_3988000_add_reserve_in_mul_3988009)

    let reserve_in_mul_1997:Uint256 = uint256_checked_mul(reserve_in, Uint256(1997, 0))
    let sqrt_sub_reserve_in_mul_1997:Uint256 = uint256_checked_sub_le(sqrt, reserve_in_mul_1997)

    let (amount_to_swap:Uint256,_) = uint256_unsigned_div_rem(sqrt_sub_reserve_in_mul_1997,Uint256(1994, 0))

    return (amount_to_swap)

end 
