// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {Subscription} from "../src/subscription.sol";
import {MockUSDT} from "../test/MockUSDT.sol";

contract SubscriptionTest is Test {
    Subscription public subscription;
    MockUSDT public mockUSDT;
    address public owner;
    address public subscriber1;
    address public subscriber2;

    uint256 public constant initialBalance = 1000 * 1e18;

    function setUp() public {
        owner = address(this);
        subscriber1 = vm.addr(1);
        subscriber2 = vm.addr(2);
        // Deploy MockUSDT and mint initial balances
        mockUSDT = new MockUSDT(25e18);
        mockUSDT.mint(subscriber1, initialBalance);
        mockUSDT.mint(subscriber2, initialBalance);
        // Deploy Subscription contract
        subscription = new Subscription(address(mockUSDT));
    }

    function testInitialSetup() public view {
        assertEq(subscription.owner(), owner, "Owner should be contract deployer");
        assertEq(address(subscription.USDTToken()), address(mockUSDT), "USDT address mismatch");
    }

    function testSubscribe() public {
        vm.startPrank(subscriber1);
        mockUSDT.approve(address(subscription), subscription.subscriptionFee());
        subscription.subscribe();
        (uint256 startTime, uint256 endTime, bool active) = subscription.getSubscriberDetails(subscriber1);
        assertGt(startTime, 0, "Start time should be set");
        assertGt(endTime, startTime, "End time should be after start time");
        assertTrue(active, "Subscriber should be active");
        vm.stopPrank();
    }

    function testAlreadySubscribed() public {
        vm.startPrank(subscriber1);
        mockUSDT.approve(address(subscription), subscription.subscriptionFee());
        subscription.subscribe();
        vm.expectRevert(Subscription.AlreadySubscribed.selector);
        subscription.subscribe();
        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.startPrank(subscriber1);
        mockUSDT.approve(address(subscription), subscription.subscriptionFee());
        subscription.subscribe();
        vm.stopPrank();

        // Travel time to after subscription expiry
        vm.warp(block.timestamp + subscription.subscriptionDuration() + 1);
        uint256 contractBalance = mockUSDT.balanceOf(address(subscription));
        uint256 ownerInitialBalance = mockUSDT.balanceOf(owner);
        subscription.withdraw(contractBalance);
        assertEq(
            mockUSDT.balanceOf(owner),
            ownerInitialBalance + contractBalance,
            "Owner should receive the withdrawn amount"
        );
    }

    // function testWithdrawBeforeSubscriptionEnd() public {
    //     vm.startPrank(subscriber1);
    //     mockUSDT.approve(address(subscription), subscription.subscriptionFee());
    //     subscription.subscribe();
    //     vm.stopPrank();

    //     // Simulate time passing (set timestamp to just before the subscription ends)
    //     uint256 endTime = subscription.latestSubscriptionEndTime();
    //     vm.warp(endTime - 1); // Ensure we are still within the subscription period
    //     console.log("Block timestamp:", block.timestamp);
    //     console.log("Latest subscription end time:", subscription.latestSubscriptionEndTime());
    //     // Attempt withdrawal and expect it to revert
    //     vm.expectRevert(Subscription.WithdrawBeforeSubscriptionEnd.selector);
    //     subscription.withdraw(1 * 1e18);
    // }

    function testIsSubscribed() public {
        vm.startPrank(subscriber1);
        mockUSDT.approve(address(subscription), subscription.subscriptionFee());
        subscription.subscribe();
        assertTrue(subscription.isSubscribed(subscriber1), "Subscriber should be active");
        // Travel time to after subscription expiry
        vm.warp(block.timestamp + subscription.subscriptionDuration() + 1);
        assertFalse(subscription.isSubscribed(subscriber1), "Subscriber should no longer be active");
        vm.stopPrank();
    }

    function testGetBalance() public {
        vm.startPrank(subscriber1);
        mockUSDT.approve(address(subscription), subscription.subscriptionFee());
        subscription.subscribe();
        vm.stopPrank();
        assertEq(subscription.getBalance(), subscription.subscriptionFee(), "Balance should match subscription fee");
    }
}
