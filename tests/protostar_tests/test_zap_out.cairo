%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_sub, uint256_unsigned_div_rem
from starkware.cairo.common.pow import pow
from starkware.cairo.common.alloc import alloc

@contract_interface
namespace IERC20:
    func name() -> (name : felt):
    end

    func symbol() -> (symbol : felt):
    end

    func decimals() -> (decimals : felt):
    end

    func mint(recipient : felt, amount : Uint256):
    end

    func approve(spender : felt, amount : Uint256) -> (success : felt):
    end

    func totalSupply() -> (totalSupply : Uint256):
    end

    func balanceOf(account : felt) -> (balance : Uint256):
    end
end

@contract_interface
namespace IPair:
    func get_reserves() -> (reserve0 : Uint256, reserve1 : Uint256, block_timestamp_last : felt):
    end
end

@contract_interface
namespace IRouter:
    func factory() -> (address : felt):
    end

    func sort_tokens(tokenA : felt, tokenB : felt) -> (token0 : felt, token1 : felt):
    end

    func add_liquidity(tokenA : felt, tokenB : felt, amountADesired : Uint256, amountBDesired : Uint256,
    amountAMin : Uint256, amountBMin : Uint256, to : felt, deadline : felt) -> (amountA : Uint256, amountB : Uint256, liquidity : Uint256):
    end

    func remove_liquidity(tokenA : felt, tokenB : felt, liquidity : Uint256, amountAMin : Uint256,
    amountBMin : Uint256, to : felt, deadline : felt) -> (amountA : Uint256, amountB : Uint256):
    end
end

@contract_interface
namespace IFactory:
    func create_pair(token0 : felt, token1 : felt) -> (pair : felt):
    end
    
    func get_pair(token0 : felt, token1 : felt) -> (pair : felt):
    end

    func get_all_pairs() -> (all_pairs_len : felt, all_pairs : felt*):
    end
end

@contract_interface
namespace IZapperOut:
    func owner() -> (owner: felt):
    end

    func router() -> (router: felt):
    end

    func zap_out(to_token_address: felt, from_pair_address: felt, incoming_lp: Uint256, min_tokens_rec: Uint256,
    path0_len: felt, path0: felt*, path1_len: felt, path1: felt*) -> (tokens_rec: Uint256):
    end
end


@external
func __setup__{syscall_ptr: felt*, pedersen_ptr : HashBuiltin*,  bitwise_ptr : BitwiseBuiltin*, range_check_ptr}():
    alloc_locals

    tempvar user_1_signer = 1
    tempvar user_2_signer = 2
    tempvar deployer_signer = 3
    tempvar factory_address
    tempvar router_address
    tempvar token_0_address
    tempvar token_1_address
    tempvar token_2_address

    %{ 
        context.user_1_signer = ids.user_1_signer
        context.user_2_signer = ids.user_2_signer
        context.deployer_signer = ids.deployer_signer
        context.user_1_address = deploy_contract("./contracts/test/Account.cairo", [context.user_1_signer]).contract_address
        context.user_2_address = deploy_contract("./contracts/test/Account.cairo", [context.user_2_signer]).contract_address
        context.deployer_address = deploy_contract("./contracts/test/Account.cairo", [context.deployer_signer]).contract_address
        context.token_0_address = deploy_contract("lib/cairo_contract/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [11, 1, 18, 0, 0, context.deployer_address, context.deployer_address]).contract_address
        context.token_1_address = deploy_contract("lib/cairo_contract/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [22, 2, 6, 0, 0, context.deployer_address, context.deployer_address]).contract_address
        context.token_2_address = deploy_contract("lib/cairo_contract/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [22, 2, 6, 0, 0, context.deployer_address, context.deployer_address]).contract_address
        context.declared_pair_class_hash = declare("./contracts/test/AMM/Pair.cairo").class_hash
        context.factory_address = deploy_contract("./contracts/test/AMM/Factory.cairo", [context.declared_pair_class_hash, context.deployer_address]).contract_address
        context.router_address = deploy_contract("./contracts/test/AMM/Router.cairo", [context.factory_address]).contract_address
        context.zapper_address = deploy_contract("./contracts/ZapperOut.cairo", [context.router_address, context.deployer_address]).contract_address
        ids.factory_address = context.factory_address
        ids.router_address = context.router_address
        ids.token_0_address = context.token_0_address
        ids.token_1_address = context.token_1_address
        ids.token_2_address = context.token_2_address
    %}
    
    let (sorted_token_0_address, sorted_token_1_address) = IRouter.sort_tokens(contract_address = router_address, tokenA = token_0_address, tokenB = token_1_address)
    let (pair_address) = IFactory.create_pair(contract_address=factory_address, token0 = sorted_token_0_address, token1 = sorted_token_1_address)
    
    let (sorted_token_1_address, sorted_token_2_address) = IRouter.sort_tokens(contract_address = router_address, tokenA = token_1_address, tokenB = token_2_address)
    let (other_pair_address) = IFactory.create_pair(contract_address=factory_address, token0 = sorted_token_1_address, token1 = sorted_token_2_address)

    %{
        context.sorted_token_0_address = ids.sorted_token_0_address
        context.sorted_token_1_address = ids.sorted_token_1_address
        context.sorted_token_2_address = ids.sorted_token_2_address
        context.pair_address = ids.pair_address
        context.other_pair_address = ids.other_pair_address
    %}
    return ()
end


@external
func test_zap_out_to_pair_token{syscall_ptr: felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    local user_1_address
    local user_2_address
    local token_0_address
    local token_1_address
    local router_address
    local pair_address
    local zapper_address

    %{  
        ids.user_1_address = context.user_1_address
        ids.user_2_address = context.user_2_address
        ids.token_0_address = context.token_0_address
        ids.token_1_address = context.token_1_address
        ids.router_address = context.router_address
        ids.pair_address = context.pair_address
        ids.zapper_address = context.zapper_address
    %}

    ### Mint a lot of tokens to user 1

    let (token_0_decimals) = IERC20.decimals(contract_address=token_0_address)
    let (token_0_multiplier) = pow(10, token_0_decimals)
    
    let (token_1_decimals) = IERC20.decimals(contract_address=token_1_address)
    let (token_1_multiplier) = pow(10, token_1_decimals)
    
    let amount_to_mint_token_0 = 100 * token_0_multiplier
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_0_address) %}
    IERC20.mint(contract_address=token_0_address, recipient=user_1_address, amount=Uint256(amount_to_mint_token_0, 0))
    %{ stop_prank() %}

    let amount_to_mint_token_1 = 100 * token_1_multiplier
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_1_address) %}
    IERC20.mint(contract_address=token_1_address, recipient=user_1_address, amount=Uint256(amount_to_mint_token_1, 0))
    %{ stop_prank() %}
    
    ### Add liquidity on behalf of user 1
    
    let amount_token_0 = 20 * token_0_multiplier
    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.token_0_address) %}
    IERC20.approve(contract_address = token_0_address, spender = router_address, amount = Uint256(amount_token_0, 0))
    %{ stop_prank() %}
    
    let amount_token_1 = 40 * token_1_multiplier
    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.token_1_address) %}
    IERC20.approve(contract_address = token_1_address, spender = router_address, amount = Uint256(amount_token_1, 0))
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.router_address) %}
    let (amountA : Uint256, amountB : Uint256, liquidity : Uint256) = IRouter.add_liquidity(contract_address = router_address, tokenA = token_0_address, tokenB = token_1_address, amountADesired = Uint256(amount_token_0, 0), amountBDesired = Uint256(amount_token_1, 0), amountAMin = Uint256(1,0), amountBMin = Uint256(1,0), to = user_1_address, deadline = 0)
    %{ stop_prank() %}
    
    let (user_1_initial_token_1_balance) = IERC20.balanceOf(contract_address = token_1_address, account = user_1_address)

    ### Zap out half of supplied liquidity

    let (liquidity_token_decimals) = IERC20.decimals(contract_address=pair_address)
    let (liquidity_token_multiplier) = pow(10, liquidity_token_decimals)
    
    let (zap_out_amount,_) =  uint256_unsigned_div_rem(liquidity,Uint256(2,0))
    # let zap_out_amount = Uint256(10000000000, 0)      # Todo: Increase this to a reasonable amount
  
    ## Zap Out

    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.pair_address) %}
    IERC20.approve(contract_address = pair_address, spender = zapper_address, amount = zap_out_amount)
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.zapper_address) %}
    
    let path0 : felt* = alloc()
    assert [path0] = token_0_address
    assert [path0 + 1] = token_1_address
    
    let path1 : felt* = alloc()
    assert [path1] = token_1_address
    assert [path1 + 1] = token_1_address
    let (tokens_rec) = IZapperOut.zap_out(contract_address=zapper_address, to_token_address=token_1_address, from_pair_address=pair_address, incoming_lp=zap_out_amount, min_tokens_rec=Uint256(0, 0), path0_len=2, path0=path0, path1_len=2, path1=path1)
    %{ stop_prank() %}

    ### Perform assertions

    let (user_1_pair_balance) = IERC20.balanceOf(contract_address = pair_address, account = user_1_address)
    let (user_1_expected_pair_balance: Uint256) = uint256_sub(liquidity, zap_out_amount)
    assert user_1_pair_balance = user_1_expected_pair_balance

    let (user_1_token_balance) = IERC20.balanceOf(contract_address = token_1_address, account = user_1_address)
    let (user_1_expected_token_balance: Uint256, is_overflow) = uint256_add(user_1_initial_token_1_balance, tokens_rec)
    assert user_1_token_balance = user_1_expected_token_balance

    return ()
end


@external
func test_zap_out_to_other_token{syscall_ptr: felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    local user_1_address
    local user_2_address
    local token_0_address
    local token_1_address
    local token_2_address
    local router_address
    local pair_address
    local other_pair_address
    local zapper_address

    %{  
        ids.user_1_address = context.user_1_address
        ids.user_2_address = context.user_2_address
        ids.token_0_address = context.token_0_address
        ids.token_1_address = context.token_1_address
        ids.token_2_address = context.token_2_address
        ids.router_address = context.router_address
        ids.pair_address = context.pair_address
        ids.zapper_address = context.zapper_address
    %}

    ### Mint a lot of tokens to user 2

    let (token_0_decimals) = IERC20.decimals(contract_address=token_0_address)
    let (token_0_multiplier) = pow(10, token_0_decimals)
    
    let (token_1_decimals) = IERC20.decimals(contract_address=token_1_address)
    let (token_1_multiplier) = pow(10, token_1_decimals)

    let (token_2_decimals) = IERC20.decimals(contract_address=token_2_address)
    let (token_2_multiplier) = pow(10, token_2_decimals)
    
    let amount_to_mint_token_0 = 100 * token_0_multiplier
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_0_address) %}
    IERC20.mint(contract_address=token_0_address, recipient=user_2_address, amount=Uint256(amount_to_mint_token_0, 0))
    %{ stop_prank() %}

    let amount_to_mint_token_1 = 100 * token_1_multiplier
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_1_address) %}
    IERC20.mint(contract_address=token_1_address, recipient=user_2_address, amount=Uint256(amount_to_mint_token_1, 0))
    %{ stop_prank() %}

    let amount_to_mint_token_2 = 120 * token_2_multiplier
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_2_address) %}
    IERC20.mint(contract_address=token_2_address, recipient=user_2_address, amount=Uint256(amount_to_mint_token_2, 0))
    %{ stop_prank() %}
    
    ### Add liquidity on behalf of user 2
    
    # Add liquidity to token_0 / token_2 and token_1 / token_2 pairs such that the user can zap out
    # of the token_0 / token_1 pair to token_2

    let amount_token_0 = 40 * token_0_multiplier
    %{ stop_prank = start_prank(ids.user_2_address, target_contract_address=ids.token_0_address) %}
    IERC20.approve(contract_address = token_0_address, spender = router_address, amount = Uint256(amount_token_0, 0))
    %{ stop_prank() %}
    
    let amount_token_2 = 60 * token_2_multiplier
    %{ stop_prank = start_prank(ids.user_2_address, target_contract_address=ids.token_2_address) %}
    IERC20.approve(contract_address = token_2_address, spender = router_address, amount = Uint256(amount_token_2, 0))
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.user_2_address, target_contract_address=ids.router_address) %}
    let (amountA : Uint256, amountB : Uint256, liquidity : Uint256) = IRouter.add_liquidity(contract_address = router_address, tokenA = token_0_address, tokenB = token_2_address, amountADesired = Uint256(amount_token_0, 0), amountBDesired = Uint256(amount_token_2, 0), amountAMin = Uint256(1,0), amountBMin = Uint256(1,0), to = user_2_address, deadline = 0)
    %{ stop_prank() %}
    
    let amount_token_1 = 40 * token_1_multiplier
    %{ stop_prank = start_prank(ids.user_2_address, target_contract_address=ids.token_1_address) %}
    IERC20.approve(contract_address = token_1_address, spender = router_address, amount = Uint256(amount_token_1, 0))
    %{ stop_prank() %}
    
    let amount_token_2 = 60 * token_2_multiplier
    %{ stop_prank = start_prank(ids.user_2_address, target_contract_address=ids.token_2_address) %}
    IERC20.approve(contract_address = token_2_address, spender = router_address, amount = Uint256(amount_token_2, 0))
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.user_2_address, target_contract_address=ids.router_address) %}
    let (amountA : Uint256, amountB : Uint256, liquidity : Uint256) = IRouter.add_liquidity(contract_address = router_address, tokenA = token_1_address, tokenB = token_2_address, amountADesired = Uint256(amount_token_1, 0), amountBDesired = Uint256(amount_token_2, 0), amountAMin = Uint256(1,0), amountBMin = Uint256(1,0), to = user_2_address, deadline = 0)
    %{ stop_prank() %}

     ### Mint a lot of tokens to user 1 to add liquidity to token_0 / token_1 pool

    let (token_0_decimals) = IERC20.decimals(contract_address=token_0_address)
    let (token_0_multiplier) = pow(10, token_0_decimals)
    
    let (token_1_decimals) = IERC20.decimals(contract_address=token_1_address)
    let (token_1_multiplier) = pow(10, token_1_decimals)
    
    let amount_to_mint_token_0 = 100 * token_0_multiplier
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_0_address) %}
    IERC20.mint(contract_address=token_0_address, recipient=user_1_address, amount=Uint256(amount_to_mint_token_0, 0))
    %{ stop_prank() %}

    let amount_to_mint_token_1 = 100 * token_1_multiplier
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_1_address) %}
    IERC20.mint(contract_address=token_1_address, recipient=user_1_address, amount=Uint256(amount_to_mint_token_1, 0))
    %{ stop_prank() %}
    
    ### Add liquidity on behalf of user 1
    
    let amount_token_0 = 20 * token_0_multiplier
    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.token_0_address) %}
    IERC20.approve(contract_address = token_0_address, spender = router_address, amount = Uint256(amount_token_0, 0))
    %{ stop_prank() %}
    
    let amount_token_1 = 40 * token_1_multiplier
    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.token_1_address) %}
    IERC20.approve(contract_address = token_1_address, spender = router_address, amount = Uint256(amount_token_1, 0))
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.router_address) %}
    let (amountA : Uint256, amountB : Uint256, liquidity : Uint256) = IRouter.add_liquidity(contract_address = router_address, tokenA = token_0_address, tokenB = token_1_address, amountADesired = Uint256(amount_token_0, 0), amountBDesired = Uint256(amount_token_1, 0), amountAMin = Uint256(1,0), amountBMin = Uint256(1,0), to = user_1_address, deadline = 0)
    %{ stop_prank() %}
    
    let (user_1_initial_token_2_balance) = IERC20.balanceOf(contract_address = token_2_address, account = user_1_address)

    ### Zap out half of supplied liquidity

    let (liquidity_token_decimals) = IERC20.decimals(contract_address=pair_address)
    let (liquidity_token_multiplier) = pow(10, liquidity_token_decimals)
    
    let (zap_out_amount,_) =  uint256_unsigned_div_rem(liquidity,Uint256(2,0))
    # let zap_out_amount = Uint256(20000000, 0)      # Todo: Increase this to a reasonable amount

    ### Zap Out

    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.pair_address) %}
    IERC20.approve(contract_address = pair_address, spender = zapper_address, amount = zap_out_amount)
    %{ stop_prank() %}

    
    let (sorted_token_0_address, sorted_token_1_address) = IRouter.sort_tokens(contract_address = router_address, tokenA = token_0_address, tokenB = token_1_address)

    let path0 : felt* = alloc()
    assert [path0] = sorted_token_0_address
    assert [path0 + 1] = token_2_address
    
    let path1 : felt* = alloc()
    assert [path1] = sorted_token_1_address
    assert [path1 + 1] = token_2_address
    
    %{ stop_prank = start_prank(context.user_1_address, target_contract_address=ids.zapper_address) %}
    let (tokens_rec) = IZapperOut.zap_out(contract_address=zapper_address, to_token_address=token_2_address, from_pair_address=pair_address, incoming_lp=zap_out_amount, min_tokens_rec=Uint256(0, 0), path0_len=2, path0=path0, path1_len=2, path1=path1)
    %{ stop_prank() %}

    ### Perform assertions

    let (user_1_pair_balance) = IERC20.balanceOf(contract_address = pair_address, account = user_1_address)
    let (user_1_expected_pair_balance: Uint256) = uint256_sub(liquidity, zap_out_amount)
    assert user_1_pair_balance = user_1_expected_pair_balance

    let (user_1_token_balance) = IERC20.balanceOf(contract_address = token_2_address, account = user_1_address)
    let (user_1_expected_token_2_balance: Uint256, is_overflow) = uint256_add(user_1_initial_token_2_balance, tokens_rec)
    assert user_1_token_balance = user_1_expected_token_2_balance

    return ()
end
