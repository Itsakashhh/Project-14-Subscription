// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function decimals() external view returns (uint8);
}

abstract contract Ownable {
    address private _owner;

    error Unauthorized();
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address initialOwner) {
        require(initialOwner != address(0), "Invalid owner address");
        _transferOwnership(initialOwner);
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) {
            revert Unauthorized();
        }
        _;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid new owner address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status;

    error ReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        if (_status == ENTERED) {
            revert ReentrantCall();
        }
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
}

contract Subscription is Ownable, ReentrancyGuard {
    IERC20 public immutable USDTToken;
    uint256 public constant subscriptionFee = 25 * 1e18; // 25 USDT
    uint256 public constant subscriptionDuration = 30 days; // 30 Days duration

    struct Subscriber {
        uint256 startTime;
        uint256 endTime;
    }

    mapping(address => Subscriber) public subscribers;
    uint256 public totalSubscribers;
    uint256 public latestSubscriptionEndTime;

    // Custom Errors
    error AlreadySubscribed();
    error TransferFailed();
    error InsufficientBalance();
    error ZeroAmount();
    error WithdrawBeforeSubscriptionEnd();

    event Subscribed(address indexed subscriber, uint256 startTime, uint256 endTime);
    event Withdrawn(address indexed owner, uint256 amount);

    constructor(address usdtAddress) Ownable(msg.sender) {
        if (usdtAddress == address(0)) revert ZeroAmount();
        USDTToken = IERC20(usdtAddress);
    }

    function subscribe() external nonReentrant {
        if (subscribers[msg.sender].endTime >= block.timestamp) revert AlreadySubscribed();

        // Ensure subscriber has enough balance
        uint256 subscriberBalance = USDTToken.balanceOf(msg.sender);
        if (subscriberBalance < subscriptionFee) revert TransferFailed();

        // Transfer subscription fee from subscriber to contract
        bool success = USDTToken.transferFrom(msg.sender, address(this), subscriptionFee); // Changed back to `transfer`
        if (!success) revert TransferFailed();

        // Update subscription details
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + subscriptionDuration;

        // Update latest subscription end time
        if (endTime > latestSubscriptionEndTime) {
            latestSubscriptionEndTime = endTime;
        }


        subscribers[msg.sender] = Subscriber(startTime, endTime);
        totalSubscribers++;

        emit Subscribed(msg.sender, startTime, endTime);
    }

    function withdraw(uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0) revert ZeroAmount();
        uint256 contractBalance = USDTToken.balanceOf(address(this));
        if (amount > contractBalance) revert InsufficientBalance();
        // Ensure the latest subscription has expired
        // if (block.timestamp < latestSubscriptionEndTime) {
        //   revert WithdrawBeforeSubscriptionEnd();
        //}

        bool success = USDTToken.transfer(owner(), amount);
        if (!success) revert TransferFailed();

        emit Withdrawn(owner(), amount);
    }

    function isSubscribed(address subscriber) external view returns (bool) {
        return block.timestamp < subscribers[subscriber].endTime;
    }

    function getSubscriberDetails(address subscriber)
        external
        view
        returns (uint256 startTime, uint256 endTime, bool active)
    {
        Subscriber memory sub = subscribers[subscriber];
        bool activeStatus = block.timestamp < sub.endTime;
        return (sub.startTime, sub.endTime, activeStatus);
    }

    function getBalance() external view returns (uint256) {
        return USDTToken.balanceOf(address(this));
    }

}
