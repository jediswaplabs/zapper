%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_not_zero, assert_not_equal
from starkware.cairo.common.alloc import alloc

#
# Storage
#

@storage_var
func _num_pairs() -> (num: felt):
end

@storage_var
func _all_pairs(index: felt) -> (address: felt):
end

@storage_var
func _pair(token0: felt, token1: felt) -> (pair: felt):
end

@storage_var
func _fee_to() -> (address: felt):
end

#
# Storage Ownable
#

@storage_var
func _owner() -> (address: felt):
end

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

# An event emitted whenever set_pair() is called.
@event
func pair_added(token0: felt, token1: felt, pair: felt, total_pairs: felt):
end

#
# Constructor
#

@constructor
func constructor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(initial_owner: felt):
    # get_caller_address() returns '0' in the constructor;
    # therefore, initial_owner parameter is included
    assert_not_zero(initial_owner)
    _owner.write(initial_owner)
    _fee_to.write(0)
    _num_pairs.write(0)
    return ()
end

#
# Getters
#

@view
func get_all_pairs{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (all_pairs_len: felt, all_pairs: felt*):
    alloc_locals
    let (num_pairs) = _num_pairs.read()
    let (local all_pairs : felt*) = alloc()
    let (all_pairs_end: felt*) = _build_all_pairs_array(0, num_pairs, all_pairs)
    return (num_pairs, all_pairs)
end

@view
func get_pair_for{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(token0: felt, token1: felt) -> (pair: felt):
    let (pair) = _pair.read(token0, token1)
    return (pair)
end

@view
func fee_to{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (address: felt):
    let (address) = _fee_to.read()
    return (address)
end

@view
func owner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (address: felt):
    let (address) = _owner.read()
    return (address)
end

#
# Setters
#

@external
func set_pair{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(token0: felt, token1: felt, pair: felt):
    _only_owner()
    assert_not_zero(token0)
    assert_not_zero(token1)
    assert_not_zero(pair)
    assert_not_equal(token0, token1)
    let (existing_pair) = _pair.read(token0, token1)
    assert existing_pair = 0
    _pair.write(token0, token1, pair)
    _pair.write(token1, token0, pair)
    let (num_pairs) = _num_pairs.read()
    _all_pairs.write(num_pairs, pair)
    _num_pairs.write(num_pairs + 1)
    pair_added.emit(token0=token0, token1=token1, pair=pair, total_pairs=num_pairs + 1)
    return ()
end

@external
func update_fee_to{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_fee_to: felt):
    _only_owner()
    assert_not_zero(new_fee_to)
    _fee_to.write(new_fee_to)
    return ()
end

#
# Setters Ownable
#

@external
func initiate_ownership_transfer{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(future_owner: felt) -> (future_owner: felt):
    _only_owner()
    let (current_owner) = _owner.read()
    assert_not_zero(future_owner)
    _future_owner.write(future_owner)
    owner_change_initiated.emit(current_owner=current_owner, future_owner=future_owner)
    return (future_owner=future_owner)
end

@external
func accept_ownership{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (current_owner) = _owner.read()
    let (future_owner) = _future_owner.read()
    let (caller) = get_caller_address()
    assert future_owner = caller
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
    assert owner = caller
    return ()
end

func _build_all_pairs_array{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(current_index: felt, num_pairs: felt, all_pairs: felt*) -> (all_pairs: felt*):
    alloc_locals
    if current_index == num_pairs:
        return (all_pairs)
    end
    let (current_pair) = _all_pairs.read(current_index)
    assert [all_pairs] = current_pair
    return _build_all_pairs_array(current_index + 1, num_pairs, all_pairs + 1)
end
