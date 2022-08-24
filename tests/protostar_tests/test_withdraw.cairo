%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_sub
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
namespace IZapper:
    func withdraw_tokens(tokens_len: felt, tokens: felt*):
    end
end

@contract_interface
namespace IZapperOut:
    func withdraw_tokens(tokens_len: felt, tokens: felt*):
    end
end


@external
func __setup__{syscall_ptr: felt*, range_check_ptr}():
    alloc_locals

    tempvar deployer_signer = 3

    %{ 
        context.deployer_signer = ids.deployer_signer
        context.deployer_address = deploy_contract("./contracts/test/Account.cairo", [context.deployer_signer]).contract_address
        context.token_0_address = deploy_contract("lib/cairo_contract/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [11, 1, 18, 0, 0, context.deployer_address, context.deployer_address]).contract_address
        context.token_1_address = deploy_contract("lib/cairo_contract/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [22, 2, 6, 0, 0, context.deployer_address, context.deployer_address]).contract_address
        context.token_2_address = deploy_contract("lib/cairo_contract/src/openzeppelin/token/erc20/presets/ERC20Mintable.cairo", [22, 2, 6, 0, 0, context.deployer_address, context.deployer_address]).contract_address
        context.declared_pair_class_hash = declare("./contracts/test/AMM/Pair.cairo").class_hash
        context.factory_address = deploy_contract("./contracts/test/AMM/Factory.cairo", [context.declared_pair_class_hash, context.deployer_address]).contract_address
        context.router_address = deploy_contract("./contracts/test/AMM/Router.cairo", [context.factory_address]).contract_address
    %}

    return ()
end


@external
func test_withdraw_zap_in{syscall_ptr: felt*, range_check_ptr}():
    alloc_locals

    local deployer_address
    local contract_address
    local token_0_address
    local token_1_address
    local token_2_address

    %{ 
        ids.deployer_address = context.deployer_address        
        context.contract_address = deploy_contract("./contracts/Zapper.cairo", [context.router_address, context.deployer_address]).contract_address
        ids.contract_address = context.contract_address
        ids.token_0_address = context.token_0_address
        ids.token_1_address = context.token_1_address
        ids.token_2_address = context.token_2_address
    %}

    ### Mint a lot of tokens to Zapper contract

    let (token_0_decimals) = IERC20.decimals(contract_address=token_0_address)
    let (token_0_multiplier) = pow(10, token_0_decimals)
    
    let (token_1_decimals) = IERC20.decimals(contract_address=token_1_address)
    let (token_1_multiplier) = pow(10, token_1_decimals)

    let (token_2_decimals) = IERC20.decimals(contract_address=token_2_address)
    let (token_2_multiplier) = pow(10, token_2_decimals)
    
    let amount_to_mint_token_0 = 100 * token_0_multiplier
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_0_address) %}
    IERC20.mint(contract_address=token_0_address, recipient=contract_address, amount=Uint256(amount_to_mint_token_0, 0))
    %{ stop_prank() %}

    let amount_to_mint_token_1 = 100 * token_1_multiplier
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_1_address) %}
    IERC20.mint(contract_address=token_1_address, recipient=contract_address, amount=Uint256(amount_to_mint_token_1, 0))
    %{ stop_prank() %}

    let amount_to_mint_token_2 = 100 * token_2_multiplier
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_2_address) %}
    IERC20.mint(contract_address=token_2_address, recipient=contract_address, amount=Uint256(amount_to_mint_token_2, 0))
    %{ stop_prank() %}
    
    let tokens : felt* = alloc()
    assert [tokens] = token_0_address
    assert [tokens + 1] = token_1_address
    assert [tokens + 2] = token_2_address

    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.contract_address) %}
    IZapper.withdraw_tokens(contract_address=contract_address, tokens_len = 3, tokens = tokens)
    %{ stop_prank() %}

    ### Validate all tokens have been withdrawn from Zapper contract to deployer account

    let (deployer_token_0_balance) = IERC20.balanceOf(contract_address = token_0_address, account = deployer_address)
    assert deployer_token_0_balance = Uint256(amount_to_mint_token_0, 0)

    let (deployer_token_1_balance) = IERC20.balanceOf(contract_address = token_1_address, account = deployer_address)
    assert deployer_token_1_balance = Uint256(amount_to_mint_token_1, 0)

    let (deployer_token_2_balance) = IERC20.balanceOf(contract_address = token_2_address, account = deployer_address)
    assert deployer_token_2_balance = Uint256(amount_to_mint_token_2, 0)
    
    return ()
end


@external
func test_withdraw_zap_out{syscall_ptr: felt*, range_check_ptr}():
    alloc_locals

    local deployer_address
    local contract_address
    local token_0_address
    local token_1_address
    local token_2_address

    %{ 
        ids.deployer_address = context.deployer_address        
        context.contract_address = deploy_contract("./contracts/ZapperOut.cairo", [context.router_address, context.deployer_address]).contract_address
        ids.contract_address = context.contract_address
        ids.token_0_address = context.token_0_address
        ids.token_1_address = context.token_1_address
        ids.token_2_address = context.token_2_address
    %}

    ### Mint a lot of tokens to ZapperOut contract

    let (token_0_decimals) = IERC20.decimals(contract_address=token_0_address)
    let (token_0_multiplier) = pow(10, token_0_decimals)
    
    let (token_1_decimals) = IERC20.decimals(contract_address=token_1_address)
    let (token_1_multiplier) = pow(10, token_1_decimals)

    let (token_2_decimals) = IERC20.decimals(contract_address=token_2_address)
    let (token_2_multiplier) = pow(10, token_2_decimals)
    
    let amount_to_mint_token_0 = 100 * token_0_multiplier
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_0_address) %}
    IERC20.mint(contract_address=token_0_address, recipient=contract_address, amount=Uint256(amount_to_mint_token_0, 0))
    %{ stop_prank() %}

    let amount_to_mint_token_1 = 100 * token_1_multiplier
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_1_address) %}
    IERC20.mint(contract_address=token_1_address, recipient=contract_address, amount=Uint256(amount_to_mint_token_1, 0))
    %{ stop_prank() %}

    let amount_to_mint_token_2 = 100 * token_2_multiplier
    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.token_2_address) %}
    IERC20.mint(contract_address=token_2_address, recipient=contract_address, amount=Uint256(amount_to_mint_token_2, 0))
    %{ stop_prank() %}
    
    let tokens : felt* = alloc()
    assert [tokens] = token_0_address
    assert [tokens + 1] = token_1_address
    assert [tokens + 2] = token_2_address

    %{ stop_prank = start_prank(context.deployer_address, target_contract_address=ids.contract_address) %}
    IZapperOut.withdraw_tokens(contract_address=contract_address, tokens_len = 3, tokens = tokens)
    %{ stop_prank() %}

    ### Validate all tokens have been withdrawn from Zapper contract to deployer account

    let (deployer_token_0_balance) = IERC20.balanceOf(contract_address = token_0_address, account = deployer_address)
    assert deployer_token_0_balance = Uint256(amount_to_mint_token_0, 0)

    let (deployer_token_1_balance) = IERC20.balanceOf(contract_address = token_1_address, account = deployer_address)
    assert deployer_token_1_balance = Uint256(amount_to_mint_token_1, 0)

    let (deployer_token_2_balance) = IERC20.balanceOf(contract_address = token_2_address, account = deployer_address)
    assert deployer_token_2_balance = Uint256(amount_to_mint_token_2, 0)
    
    return ()
end