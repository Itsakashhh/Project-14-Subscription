// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function mint(address to, uint256 value) external returns (bool);
}

contract MockUSDT is IERC20 {
    error TransferAmountExceedsBalance();
    error InvalidRecipient();
    error ZeroAmount();
    error TransferAmountExceedsAllowance();

    string public constant name = "MockUSDT";
    string public constant symbol = "USDT";
    uint8 public constant decimals = 18;
    uint256 private _totalSupply;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Mint(address indexed to, uint256 value);

    constructor(uint256 initialSupply) {
        _mint(msg.sender, initialSupply);
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 value) external override returns (bool) {
        if (_balances[msg.sender] < value) {
            revert TransferAmountExceedsBalance();
        }
        _balances[msg.sender] -= value;
        _balances[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external override returns (bool) {
        if (spender == address(0)) revert InvalidRecipient();
        _allowances[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        if (_balances[from] < value) revert TransferAmountExceedsBalance();
        if (_allowances[from][msg.sender] < value) revert TransferAmountExceedsAllowance();

        _balances[from] -= value;
        _balances[to] += value;

        // Reduce the allowance
        _allowances[from][msg.sender] -= value;

        emit Transfer(from, to, value);
        return true;
    }

    function mint(address to, uint256 value) external override returns (bool) {
        if (to == address(0)) revert InvalidRecipient();
        if (value == 0) revert ZeroAmount();

        _mint(to, value);
        return true;
    }

    function _mint(address to, uint256 value) private {
        _totalSupply += value;
        _balances[to] += value;

        emit Mint(to, value);
        emit Transfer(address(0), to, value);
    }
}
