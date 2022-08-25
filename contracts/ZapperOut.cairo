%lang starknet

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


    func remove_liquidity(tokenA: felt, tokenB: felt, liquidity: Uint256, amountAMin: Uint256, amountBMin: Uint256, 
    to: felt, deadline: felt) -> (amountA: Uint256, amountB: Uint256):
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

# @notice An event emitted whenever zap out.
@event
func Zapped_out(sender: felt, pool_address: felt, to_token: felt, tokens_rec: Uint256):
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
    }( new_goodwill: felt):
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
    with_attr error_message("ZapperOut::accept_ownership::Only future owner can accept"):
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
    with_attr error_message("ZapperOut::_only_owner::Caller must be owner"):
        assert owner = caller
    end
    return ()
end



#
# Externals
#

# @notice Zap out liquidity tokens to receieve to tokens
# @dev `caller` should have already given the router an allowance of at least incoming_lp on from_pair Token
# @param to_token_address Address of to_token
# @param from_pair_address Address of from_pair
# @param incoming_lp The amount of from_pair to remove as liquidity
# @param min_poolmin_tokens_rec_token Bounds the extent to which to_token receieved before the transaction reverts.
# @param path0_len The length of route to swap token0 of pair to to_token
# @param path0 The route to swap token0 of pair to to_token
# @param path1_len The length of route to swap token1 of pair to to_token
# @param path1 The route to swap token1 of pair to to_token
# @return tokens_rec The amount of to_token receieved
@external
func zap_out{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(to_token_address: felt, from_pair_address: felt, incoming_lp: Uint256, min_tokens_rec: Uint256,
    path0_len: felt, path0: felt*, path1_len: felt, path1: felt*) -> (tokens_rec: Uint256):
    alloc_locals
    assert_not_zero(from_pair_address)
    assert_not_zero(to_token_address)
    uint256_check(incoming_lp)

    let (sender) = get_caller_address()

    let(amount0:Uint256, amount1:Uint256) = _remove_lquidity(from_pair_address,incoming_lp)

    let (tokens_rec: Uint256) = _swap_tokens(from_pair_address, amount0, amount1, to_token_address, path0_len, path0, path1_len, path1)

    let (is_tokens_rec_less_than_min_tokens_rec) = uint256_lt(tokens_rec,min_tokens_rec)
    with_attr error_message("ZapperOut::zap_out:: High Slippage"):
        assert is_tokens_rec_less_than_min_tokens_rec = 0
    end


    let (goodwill: felt) = _goodwill.read()
    let (goodwill_amount:Uint256)  = uint256_checked_mul(tokens_rec,Uint256(goodwill,0))
    let (goodwill_portion:Uint256,_) = uint256_unsigned_div_rem(goodwill_amount,Uint256(10000,0))
    let tokens_rec_after_fees: Uint256 = uint256_checked_sub_lt(tokens_rec,goodwill_portion)

    IERC20.transfer(contract_address=to_token_address, recipient=sender, amount=tokens_rec_after_fees)

    Zapped_out.emit(sender = sender, pool_address = from_pair_address, to_token = to_token_address, tokens_rec = tokens_rec_after_fees)
    return (tokens_rec_after_fees)
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

func _remove_lquidity{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(from_pair_address: felt, incoming_lp: Uint256) -> (amount0: Uint256, amount1: Uint256):
    alloc_locals

    let (token0: felt, token1: felt) = _get_pair_tokens(from_pair_address)
    let (router: felt) = _jedi_router.read() 
    let (contract_address: felt) = get_contract_address()
    let (sender: felt) = get_caller_address()
    let (deadline: felt) = _deadline.read()

    IERC20.transferFrom(contract_address = from_pair_address, sender = sender, recipient = contract_address, amount = incoming_lp)
    IERC20.approve(contract_address = from_pair_address, spender = router, amount = Uint256(0,0))
    IERC20.approve(contract_address = from_pair_address, spender = router, amount = incoming_lp)

    let (amount0: Uint256, amount1: Uint256) = IRouter.remove_liquidity(router, token0, token1, incoming_lp, Uint256(1,0), Uint256(1,0), contract_address, deadline)

    with_attr error_message("ZapperOut::_remove_lquidity:: Removed Insufficient Liquidity"):
        let (is_amount0_equal_to_zero) =  uint256_eq(amount0, Uint256(0, 0))
        assert is_amount0_equal_to_zero = 0
        let (is_amount1_equal_to_zero) =  uint256_eq(amount1, Uint256(0, 0))
        assert is_amount1_equal_to_zero = 0
    end

    return (amount0, amount1)
end

func _swap_tokens{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(from_pair_address: felt, amount0: Uint256, amount1: Uint256, to_token: felt, path0_len: felt, path0: felt*, path1_len: felt, path1: felt*) -> (tokens_bought: Uint256):
    alloc_locals

    let (token0: felt, token1: felt) = _get_pair_tokens(from_pair_address)
    local tokens_bought0: Uint256
    local tokens_bought1: Uint256
    if token0 == to_token:
        assert tokens_bought0 = amount0
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        let (amount_rec: Uint256) = _fill_quote(token0, to_token, amount0, path0_len, path0)
        assert tokens_bought0 = amount_rec
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    if token1 == to_token:
        assert tokens_bought1 = amount1
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        let (amount_rec: Uint256) = _fill_quote(token1, to_token, amount1, path1_len, path1)
        assert tokens_bought1 = amount_rec
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    let (tokens_bought: Uint256) = uint256_checked_add(tokens_bought0, tokens_bought1)
    return (tokens_bought)

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
    }(from_token_address: felt, to_token_address: felt, amount: Uint256, path_len: felt, path: felt*) -> (amount_bought:Uint256):
    alloc_locals
        
    let (contract_address: felt) = get_contract_address()

    let initial_balance: Uint256 = IERC20.balanceOf(contract_address = to_token_address, account=contract_address)

    let (router) = _jedi_router.read()
    let (deadline) = _deadline.read()

    IERC20.approve(contract_address= from_token_address, spender= router, amount= amount)
    let (amounts_len:felt,amounts) = IRouter.swap_exact_tokens_for_tokens(contract_address = router, amountIn = amount, amountOutMin = Uint256(0, 0), path_len = path_len, path = path, to = contract_address, deadline = deadline ) 
    
    let token_bought:Uint256 = [amounts + amounts_len -2]
    let (is_token_bought_less_than_equal_zero) = uint256_le(token_bought, Uint256(0,0))
    assert is_token_bought_less_than_equal_zero = 0

    let new_balance:Uint256 = IERC20.balanceOf(contract_address= to_token_address, account=contract_address)
    let final_balance:Uint256 = uint256_checked_sub_le(new_balance, initial_balance)

    let (is_final_balance_equals_to_zero) = uint256_eq(final_balance, Uint256(0,0))
    assert is_final_balance_equals_to_zero = 0

    return (final_balance)
end



