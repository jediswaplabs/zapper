%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256
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
namespace IZapper:
    func owner() -> (owner: felt):
    end

    func router() -> (router: felt):
    end

    func zap_in(from_token_address: felt, pair_address: felt, amount: Uint256, min_pool_token: Uint256,
    path_len: felt, path: felt*, transfer_residual: felt) -> (lp_bought: Uint256):
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

    %{ 
        context.user_1_signer = ids.user_1_signer
        context.user_2_signer = ids.user_2_signer
        context.deployer_signer = ids.deployer_signer
        context.user_1_address = deploy_contract("./contracts/test/Account.cairo", [context.user_1_signer]).contract_address
        context.user_2_address = deploy_contract("./contracts/test/Account.cairo", [context.user_2_signer]).contract_address
        context.deployer_address = deploy_contract("./contracts/test/Account.cairo", [context.deployer_signer]).contract_address
        context.token_0_address = deploy_contract("lib/cairo_contracts/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [11, 1, 18, 0, 0, context.deployer_address, context.deployer_address]).contract_address
        context.token_1_address = deploy_contract("lib/cairo_contracts/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [22, 2, 6, 0, 0, context.deployer_address, context.deployer_address]).contract_address
        context.declared_pair_class_hash = declare("./contracts/test/AMM/Pair.cairo").class_hash
        context.factory_address = deploy_contract("./contracts/test/AMM/Factory.cairo", [context.declared_pair_class_hash, context.deployer_address]).contract_address
        context.router_address = deploy_contract("./contracts/test/AMM/Router.cairo", [context.factory_address]).contract_address
        context.zapper_address = deploy_contract("./contracts/Zapper.cairo", [context.router_address, context.deployer_address]).contract_address
        ids.factory_address = context.factory_address
        ids.router_address = context.router_address
        ids.token_0_address = context.token_0_address
        ids.token_1_address = context.token_1_address
    %}
    
    let (sorted_token_0_address, sorted_token_1_address) = IRouter.sort_tokens(contract_address = router_address, tokenA = token_0_address, tokenB = token_1_address)
    
    let (pair_address) = IFactory.create_pair(contract_address=factory_address, token0 = sorted_token_0_address, token1 = sorted_token_1_address)

    %{
        context.sorted_token_0_address = ids.sorted_token_0_address
        context.sorted_token_1_address = ids.sorted_token_1_address
        context.pair_address = ids.pair_address
    %}
    return ()
end


@external
func test_zap_in_from_same_token{syscall_ptr: felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
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

    ### Mint a lot of tokens to user 2

    let (token_0_decimals) = IERC20.decimals(contract_address=token_0_address)
    let (token_0_multiplier) = pow(10, token_0_decimals)
    
    let (token_1_decimals) = IERC20.decimals(contract_address=token_1_address)
    let (token_1_multiplier) = pow(10, token_1_decimals)
    
    let amount_to_mint_token_0 = 100 * token_0_multiplier
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_0_address) %}
    IERC20.mint(contract_address=token_0_address, recipient=user_2_address, amount=Uint256(amount_to_mint_token_0, 0))
    %{ stop_prank() %}

    let amount_to_mint_token_1 = 100 * token_1_multiplier
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_1_address) %}
    IERC20.mint(contract_address=token_1_address, recipient=user_2_address, amount=Uint256(amount_to_mint_token_1, 0))
    %{ stop_prank() %}
    
    ### Add liquidity on behalf of user 2
    
    let amount_token_0 = 2 * token_0_multiplier
    %{ stop_prank = start_prank(ids.user_2_address, target_contract_address=ids.token_0_address) %}
    IERC20.approve(contract_address = token_0_address, spender = router_address, amount = Uint256(amount_token_0, 0))
    %{ stop_prank() %}
    
    let amount_token_1 = 4 * token_1_multiplier
    %{ stop_prank = start_prank(ids.user_2_address, target_contract_address=ids.token_1_address) %}
    IERC20.approve(contract_address = token_1_address, spender = router_address, amount = Uint256(amount_token_1, 0))
    %{ stop_prank() %}

    %{ stop_prank = start_prank(ids.user_2_address, target_contract_address=ids.router_address) %}
    let (amountA : Uint256, amountB : Uint256, liquidity : Uint256) = IRouter.add_liquidity(contract_address = router_address, tokenA = token_0_address, tokenB = token_1_address, amountADesired = Uint256(amount_token_0, 0), amountBDesired = Uint256(amount_token_1, 0), amountAMin = Uint256(1,0), amountBMin = Uint256(1,0), to = user_2_address, deadline = 0)
    %{ stop_prank() %}
    
    ### Mint tokens to user 1

    let amount_to_mint_for_user_1 = 10 * token_0_multiplier
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_0_address) %}
    IERC20.mint(contract_address=token_0_address, recipient=user_1_address, amount=Uint256(amount_to_mint_for_user_1, 0))
    %{ stop_prank() %}

    ### Zap In

    let zap_in_amount = 10 * token_0_multiplier

    %{ stop_prank = start_prank(ids.user_1_address, target_contract_address=ids.token_0_address) %}
    IERC20.approve(contract_address = token_0_address, spender = zapper_address, amount = Uint256(zap_in_amount, 0))
    %{ stop_prank() %}

    %{ stop_prank = start_prank(context.user_1_address, target_contract_address=ids.zapper_address) %}
    let path : felt* = alloc()
    assert [path] = token_0_address
    assert [path + 1] = token_1_address
    let (lp_bought) = IZapper.zap_in(contract_address = zapper_address, from_token_address=token_0_address, pair_address=pair_address, amount=Uint256(zap_in_amount, 0), min_pool_token=Uint256(0, 0), path_len=2, path=path, transfer_residual=1)
    %{ stop_prank() %}

    ### Perform assertions

    let (user_1_pair_balance) = IERC20.balanceOf(contract_address = pair_address, account = user_1_address)
    assert user_1_pair_balance = lp_bought

    let (zapper_token_0_balance) = IERC20.balanceOf(contract_address = token_0_address, account = zapper_address)
    assert zapper_token_0_balance = Uint256(0, 0)

    let (zapper_token_1_balance) = IERC20.balanceOf(contract_address = token_1_address, account = zapper_address)
    assert zapper_token_1_balance = Uint256(0, 0)

    return ()
end