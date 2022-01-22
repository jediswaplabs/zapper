%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.math import assert_le, assert_not_zero, assert_not_equal
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import (Uint256, uint256_eq, uint256_le, uint256_check, uint256_lt, 
    uint256_add, uint256_sub, uint256_mul, uint256_unsigned_div_rem)
from starkware.cairo.common.alloc import alloc

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
    
    func get_reserves() -> (reserve0: Uint256, reserve1: Uint256):
    end

    func token0() -> (address: felt):
    end

    func token1() -> (address: felt):
    end

end

@contract_interface
namespace IWETH:
    func deposit():
    end
end

@contract_interface
namespace IRegistry:
    func get_pair_for(token0: felt, token1: felt) -> (pair: felt):
    end
end


@contract_interface
namespace IRouter:

    func _registry() -> (address: felt):
    end


    func add_liquidity(tokenA: felt, tokenB: felt, amountADesired: Uint256, amountBDesired: Uint256,
    amountAMin: Uint256, amountBMin: Uint256, to: felt, deadline: felt) -> (amountA: Uint256, amountB: Uint256, liquidity: Uint256):
    end

    func swap_exact_tokens_for_tokens(amountIn: Uint256, amountOutMin: Uint256, path_len: felt, path: felt*, 
    to: felt, deadline: felt) -> (amounts_len: felt, amounts: felt*):
    end
end


#
# Storage
#

@storage_var
func _jedi_router() -> (address: felt):
end

@storage_var
func _jedi_registry() -> (address: felt):
end

@storage_var
func _goodwill() -> (res: Uint256):
end

@storage_var
func _deadline() -> (res: felt):
end

@storage_var
func _owner() -> (address: felt):
end



#
# Constructor
#

@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        registry: felt,
        router:felt,
        owner:felt
    ):
    # get_caller_address() returns '0' in the constructor;
    # therefore, owner parameter is included
    assert_not_zero(registry)
    assert_not_zero(router)
    assert_not_zero(owner)

    _jedi_registry.write(registry)
    _jedi_router.write(router)
    _goodwill.write(Uint256(0,0))
    _owner.write(owner)
    _deadline.write(999999999999999999999999)  # set to largest number possible 
    return ()
end

#
# Getters 
#

@view
func owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (owner: felt):
    let (owner) = _owner.read()
    return (owner)
end

@view
func registry{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (registry: felt):
    let (registry) = _jedi_registry.read()
    return (registry)
end

@view
func router{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (router: felt):
    let (router) = _jedi_router.read()
    return (router)
end

@view
func goodwill{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (goodwill: Uint256):
    let (goodwill) = _goodwill.read()
    return (goodwill)
end

#
# Externals
#

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

    let goodwill:Uint256 = _goodwill.read()
    let goodwill_amount:Uint256 = uint256_mul(amount,goodwill)
    let (goodwill_portion:Uint256,_) = uint256_unsigned_div_rem(goodwill_amount,Uint256(10000,0))
    let amount_to_invest:Uint256 = uint256_sub(amount,goodwill_portion)

    # # let (lp_bought) = _perform_zap_in(from_token_address, pair_address, amount_to_invest, swap_target, swap_data, transfer_residual)
    let (lp_bought) = _perform_zap_in(from_token_address, pair_address, amount_to_invest, path_len, path, transfer_residual)

    let is_lp_bought_less_than_equal_min_pool_token:felt = uint256_le(min_pool_token,lp_bought)
    assert_not_zero(is_lp_bought_less_than_equal_min_pool_token)
    IERC20.transfer(contract_address=pair_address, recipient=sender, amount=lp_bought)
    # return (amount)
    return (lp_bought)
end

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

@external
func transfer_ownership{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_owner: felt) -> (new_owner: felt):
    _only_owner()
    assert_not_zero(new_owner)
    _owner.write(new_owner)
    return (new_owner=new_owner)
end

@external
func update_goodwill{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }( goodwill:Uint256):
    alloc_locals
    _only_owner()

    _goodwill.write(goodwill)
    return ()
end

#
# Internals
#

func _only_owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (owner) = _owner.read()
    let (caller) = get_caller_address()
    assert owner = caller
    return ()
end


func _perform_zap_in{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(from_token_address: felt, pair_address: felt, amount: Uint256, path_len: felt, 
    path: felt*, transfer_residual: felt) -> (lp_bought: Uint256):
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
        else:
            # let (temp_amt:Uint256,temp_token:felt) = _fill_quote(from_token_address, pair_address, amount, swap_target, swap_data) 
            let (temp_amt:Uint256,temp_token:felt) = _fill_quote(from_token_address, pair_address, amount, path_len, path)
            assert intermediate_amt = temp_amt
            intermediate_token = temp_token
        end
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
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
    let deadline:felt = _deadline.read()
    let(amountA:Uint256, amountB:Uint256, liquidity:Uint256) = IRouter.add_liquidity(contract_address = router, tokenA = token0,tokenB = token1, amountADesired = token0_bought, amountBDesired = token1_bought, amountAMin = Uint256(1,0), amountBMin = Uint256(1,0), to = contract_address,deadline = deadline )

    let (sender) = get_caller_address()

#   compiltion error ; reange_check_ptr revoked
    # if transfer_residual == 1:
    #     let (is_amountA_less_than_token0_bought) = uint256_lt(amountA,token0_bought)
    #     if is_amountA_less_than_token0_bought == 1 :
    #         let amount:Uint256 = uint256_sub(token0_bought,amountA)
    #         IERC20.transfer(contract_address = token0, recipient = sender, amount = amount)
    #         tempvar syscall_ptr = syscall_ptr
    #         tempvar pedersen_ptr = pedersen_ptr
    #         tempvar range_check_ptr = range_check_ptr

    #     end
    #     let (is_amountB_less_than_token1_bought) = uint256_lt(amountB,token1_bought)
    #     if is_amountB_less_than_token1_bought == 1 :
    #         let amount:Uint256 = uint256_sub(token1_bought,amountB)
    #         IERC20.transfer(contract_address = token1, recipient = sender, amount = amount)
    #         tempvar syscall_ptr = syscall_ptr
    #         tempvar pedersen_ptr = pedersen_ptr
    #         tempvar range_check_ptr = range_check_ptr

    #     end
    #     local syscall_ptr: felt* = syscall_ptr
    #     local pedersen_ptr: HashBuiltin* = pedersen_ptr
    #     local range_check_ptr = range_check_ptr
     
    # end
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


# taking path, path_len and amount as input instead of swapData because unable to call low level call
func _fill_quote{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(from_token_address: felt, pair_address: felt, amount: Uint256, path_len: felt, path: felt*) -> (amount_bought:Uint256, intermediate_token:felt):
    alloc_locals
    

    # IERC20.approve(contract_address= from_token_address, spender= swap_target, amount= amount)
    
    let(token0, token1) = _get_pair_tokens(pair_address)
    let (contract_address) = get_contract_address()

    let initial_balance0:Uint256 = IERC20.balanceOf(contract_address= token0, account=contract_address)
    let initial_balance1:Uint256 = IERC20.balanceOf(contract_address= token1, account=contract_address)

    # let (success, ) = _swapTarget.call{ value: valueToSend }(swapData); // low level call
    let (router) = _jedi_router.read()
    let (deadline) = _deadline.read()

    IERC20.approve(contract_address= from_token_address, spender= router, amount= amount)
    let (_,token_bought) = IRouter.swap_exact_tokens_for_tokens(contract_address = router, amountIn = amount, amountOutMin = Uint256(0, 0), path_len = path_len, path = path, to = contract_address, deadline = deadline ) 
    
    assert_not_zero(token_bought[path_len-1])

    let contract_token0_balance:Uint256 = IERC20.balanceOf(contract_address= token0, account=contract_address)
    let final_balance0:Uint256 = uint256_sub(contract_token0_balance, initial_balance0)
    
    let contract_token1_balance:Uint256 = IERC20.balanceOf(contract_address= token1, account=contract_address)
    let final_balance1:Uint256 = uint256_sub(contract_token1_balance, initial_balance1)

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
    # uint256_check(amount_bought)

    return (amount_bought,intermediate_token)
end

func _swap_intermediate{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(intermediate_token: felt, token0: felt, token1: felt, amount: Uint256) -> (token0_bought: Uint256, token1_bought: Uint256):
    alloc_locals
    let registry:felt = _jedi_registry.read()
    let pair_address:felt = IRegistry.get_pair_for(contract_address = registry, token0= token0, token1= token1)

    let (res0:Uint256, res1:Uint256) = IPair.get_reserves(contract_address = pair_address)
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

        let tokenA_bought:Uint256 = uint256_sub(amount,amount_to_swap)
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

        let tokenB_bought:Uint256 = uint256_sub(amount,amount_to_swap)
        assert token1_bought = tokenB_bought
    end
    return (token0_bought,token1_bought)
end

func _token_to_token{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(from_token: felt, to_token: felt, token_to_trade: Uint256) -> (token_bought_uint: Uint256):
    alloc_locals

    if from_token == to_token:
        return (token_to_trade)
    end
    let registry:felt = _jedi_registry.read()
    let router:felt = _jedi_router.read()
    IERC20.approve(contract_address = from_token, spender = router, amount = token_to_trade)

    let pair_address:felt = IRegistry.get_pair_for(contract_address = registry, token0= from_token, token1= to_token)
    assert_not_zero(pair_address)

    let (local path : felt*) = alloc()
    assert [path] = from_token
    assert [path+1] = to_token
    
    let (contract_address) = get_contract_address()
    let (deadline:felt) = _deadline.read()
    let (_,token_bought) = IRouter.swap_exact_tokens_for_tokens(contract_address = router, amountIn = token_to_trade, amountOutMin = Uint256(0, 0), path_len = 2, path = path, to = contract_address, deadline = deadline ) # using a large deadline
    assert_not_zero([token_bought+1])

    let token_bought_uint = Uint256([token_bought+1],0)
    
    return (token_bought_uint)
end

func _calculate_swap_in_amount{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(reserve_in: Uint256, user_in: Uint256) -> (amount_to_swap: Uint256):
    alloc_locals

    let user_in_mul_3988000:Uint256 = uint256_mul(user_in, Uint256(3988000, 0))
    let reserve_in_mul_user_in_mul_3988000:Uint256 = uint256_mul(reserve_in, user_in_mul_3988000)
    let reserve_in_mul_3988009:Uint256 = uint256_mul(reserve_in, Uint256(3988009, 0))
    let reserve_in_mul_user_in_mul_3988000_add_reserve_in_mul_3988009:Uint256 = uint256_add(reserve_in_mul_user_in_mul_3988000, reserve_in_mul_3988009)
    let sqrt:Uint256 = _uint256_sqrt(reserve_in_mul_user_in_mul_3988000_add_reserve_in_mul_3988009)

    let reserve_in_mul_1997:Uint256 = uint256_mul(reserve_in, Uint256(1997, 0))
    let sqrt_sub_reserve_in_mul_1997:Uint256 = uint256_sub(sqrt, reserve_in_mul_1997)

    let (amount_to_swap:Uint256,_) = uint256_unsigned_div_rem(sqrt_sub_reserve_in_mul_1997,Uint256(1994, 0))

    return (amount_to_swap)

end 


func _uint256_sqrt{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(y: Uint256) -> (z: Uint256):
    alloc_locals
    uint256_check(y)
    local z: Uint256
    let (is_y_greater_than_3) = uint256_lt(Uint256(3, 0), y)
    if is_y_greater_than_3 == 1:
        let (y_div_2: Uint256, _) = uint256_unsigned_div_rem(y, Uint256(2, 0))
        let (x: Uint256, is_overflow) = uint256_add(y_div_2, Uint256(1, 0))
        assert (is_overflow) = 0
        let (final_z: Uint256) = _build_sqrt(x, y, y)
        assert z = final_z
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        let (is_y_equal_to_0) =  uint256_eq(y, Uint256(0, 0))
        if is_y_equal_to_0 == 1:
            assert z = Uint256(0, 0)
        else:
            assert z = Uint256(1, 0)
        end
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    return (z)
end

func _build_sqrt{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(x: Uint256, y: Uint256, z: Uint256) -> (res: Uint256):
    alloc_locals
    let (is_x_less_than_z) = uint256_lt(x, z)
    if is_x_less_than_z == 1:
        let (y_div_x: Uint256, _) = uint256_unsigned_div_rem(y, x)
        let (temp_x_2: Uint256, is_overflow) = uint256_add(y_div_x, x)
        assert (is_overflow) = 0
        let (temp_x: Uint256, _) = uint256_unsigned_div_rem(temp_x_2, Uint256(2, 0))
        return _build_sqrt(temp_x, y, x)
    else:
        return (z)
    end
end




    