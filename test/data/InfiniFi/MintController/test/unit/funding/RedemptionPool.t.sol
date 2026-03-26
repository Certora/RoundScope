// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "@forge-std/Test.sol";

import {console} from "@forge-std/console.sol";
import {RedemptionPool} from "@funding/RedemptionPool.sol";
import {RedemptionQueue} from "@libraries/RedemptionQueue.sol";

/// @notice test contract for the RedemptionPool, this test inherit from the RedemptionPool
contract RedemptionPoolTest is Test, RedemptionPool {
    using RedemptionQueue for RedemptionQueue.RedemptionRequestsQueue;

    address public RECIPIENT = makeAddr("RECIPIENT");

    function _enqueueRecipients(uint256 _ticketCount, uint256 _amountPerTicket) private returns (uint256) {
        uint256 totalReallyEnqueued = 0;
        for (uint256 i = 0; i < _ticketCount; i++) {
            totalReallyEnqueued += _amountPerTicket;
            _enqueue(makeAddr(string.concat("RECIPIENT_", vm.toString(i))), _amountPerTicket);
        }

        return totalReallyEnqueued;
    }

    function _setUpFundWithManyTickets(uint256 _totalEnqueuedAmount, uint256 _redemptionCount) private {
        uint96 amountPerTicket = uint96(_totalEnqueuedAmount / _redemptionCount);
        uint256 totalReallyEnqueued = _enqueueRecipients(_redemptionCount, amountPerTicket);

        if (totalReallyEnqueued < _totalEnqueuedAmount) {
            uint256 remainingAmount = _totalEnqueuedAmount - totalReallyEnqueued;
            // we need to enqueue the remaining amount
            _enqueue(makeAddr("RECIPIENT_FINAL"), remainingAmount);
        }
    }

    function testSetUp() public view {
        assertEq(queue.length(), 0, "queue should be empty");
    }

    /// @notice test the enqueue function with a zero amount
    /// the enqueue function should revert with EnqueueAmountZero error when trying to enqueue 0 amount
    /// (which would be useless and stuff the queue)
    /// forge-config: default.allow_internal_expect_revert = true
    function testEnqueueZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(RedemptionPool.EnqueueAmountZero.selector));
        _enqueue(RECIPIENT, 0);
    }

    /// @notice test the enqueue function with a valid amount
    /// the enqueue function should add the request to the queue and increase the totalEnqueuedRedemptions
    function testEnqueueOneUser(address _recipient, uint256 _amount) public {
        vm.label(_recipient, "RECIPIENT");
        _amount = bound(_amount, 1e18, type(uint96).max); // Ensure _amount is between 1e18 and uint96 max value
        _enqueue(_recipient, _amount);
        assertEq(queue.length(), 1, "queue should have one request");
        RedemptionQueue.RedemptionRequest memory request = queue.front();
        assertEq(request.recipient, _recipient, "Error: receipient is not set correctly in request");
        assertEq(request.amount, _amount, "Error: amount is not set correctly in request");
        assertEq(totalEnqueuedRedemptions, _amount, "Error: totalEnqueuedRedemptions is not set correctly");
    }

    /// @notice test the enqueue function when the queue is too long
    /// the enqueue function should revert with QueueTooLong error when the queue is at its maximum length
    /// this is a design parameter used to avoid out of gas errors in griefing scenarios
    /// forge-config: default.allow_internal_expect_revert = true
    function testEnqueueQueueTooLong() public {
        for (uint256 i = 0; i < MAX_QUEUE_LENGTH; i++) {
            _enqueue(makeAddr(string.concat("RECIPIENT_", vm.toString(i))), 1e18);
        }

        vm.expectRevert(abi.encodeWithSelector(RedemptionPool.QueueTooLong.selector));
        _enqueue(makeAddr("RECIPIENT_LAST"), 1e18);
    }

    /// @notice test the enqueue function with two different users
    /// the enqueue function should add the requests to the queue and increase the totalEnqueuedRedemptions
    /// fuzzing the tests to ensure it works with any amount > 0 and < uint96.max
    function testEnqueueTwoDifferentUsers(address _recipient1, uint256 _amount1, address _recipient2, uint256 _amount2)
        public
    {
        _amount1 = bound(_amount1, 1e18, type(uint96).max); // Ensure _amount is between 1e18 and uint96 max value
        _amount2 = bound(_amount2, 1e18, type(uint96).max); // Ensure _amount is between 1e18 and uint96 max value
        _enqueue(_recipient1, _amount1);
        _enqueue(_recipient2, _amount2);
        assertEq(queue.length(), 2, "Error: queue should have two requests");
        RedemptionQueue.RedemptionRequest memory request1 = queue.front();
        assertEq(request1.recipient, _recipient1, "Error: receipient1's address is not set correctly in request");
        assertEq(request1.amount, _amount1, "Error: receipient1's amount is not set correctly in request");
        RedemptionQueue.RedemptionRequest memory request2 = queue.at(1);
        assertEq(request2.recipient, _recipient2, "Error: receipient2's address is not set correctly in request");
        assertEq(request2.amount, _amount2, "Error: receipient2's amount is not set correctly in request");
        assertEq(
            totalEnqueuedRedemptions,
            _amount1 + _amount2,
            "Error: totalEnqueuedRedemptions should be sum of amount1 and amount2"
        );
    }

    /// @notice this test is done to ensure we don't do specific action when a user enqueue twice
    /// the enqueue function should add the requests to the queue and increase the totalEnqueuedRedemptions
    /// it should not do anything special like update the first ticket or anything like that
    function testEnqueueTwoTimesSameUser(address _recipient, uint256 _amount1, uint256 _amount2) public {
        _amount1 = bound(_amount1, 1e18, type(uint96).max); // Ensure _amount is between 1e18 and uint96 max value
        _amount2 = bound(_amount2, 1e18, type(uint96).max); // Ensure _amount is between 1e18 and uint96 max value
        _enqueue(_recipient, _amount1);
        assertEq(totalEnqueuedRedemptions, _amount1, "Error: totalEnqueuedRedemptions should be amount1");
        _enqueue(_recipient, _amount2);
        assertEq(
            totalEnqueuedRedemptions,
            _amount1 + _amount2,
            "Error: totalEnqueuedRedemptions should be sum of amount1 and amount2"
        );
    }

    /// @notice test the claimRedemption function when there is nothing to claim
    /// the claimRedemption function should revert with NoUserPendingClaims error when the user has no pending claims
    /// forge-config: default.allow_internal_expect_revert = true
    function testClaimRedemptionWhenNothingToClaimShouldRevert(address _recipient) public {
        vm.expectRevert(abi.encodeWithSelector(RedemptionPool.NoPendingClaims.selector, _recipient));
        _claimRedemption(_recipient);
    }

    /// @notice test the fundRedemptionQueue function when the funding amount is 0
    /// the fundRedemptionQueue function should revert with FundingAmountZero error
    /// forge-config: default.allow_internal_expect_revert = true
    function testFundRedemptionQueueWithAmountZero() public {
        vm.expectRevert(abi.encodeWithSelector(RedemptionPool.FundingAmountZero.selector));
        _fundRedemptionQueue(0, 1e18);
    }

    /// @notice test the fundRedemptionQueue function when the queue is empty
    /// the fundRedemptionQueue function should return the remaining assets and the receipt amount to burn
    /// when the queue is empty, the remaining assets should be the same as the funding amount
    /// and the receipt amount to burn should be 0
    function testFundRedemptionQueueWhenQueueIsEmpty(uint256 _assetAmount) public {
        _assetAmount = bound(_assetAmount, 1e18, type(uint96).max); // Ensure _amount is between 1e18 and uint96 max value

        uint256 convertRatio = 1e18;
        (uint256 remainingAssets, uint256 receiptAmountToBurn) = _fundRedemptionQueue(_assetAmount, convertRatio);
        assertEq(remainingAssets, _assetAmount, "Error: remainingAssets should be equal to the funding amount");
        assertEq(receiptAmountToBurn, 0, "Error: receiptAmountToBurn should be 0 when the queue is empty");
    }

    /// @notice test 1 ticket in the queue with the exact amount of asset we fund the queue with
    /// the fundRedemptionQueue function should return 0 remaining assets and the receipt amount to burn
    /// should be the same as the amount enqueued
    function testFundRedemptionQueueExactAmount(uint256 _assetAmount) public {
        _assetAmount = bound(_assetAmount, 1e18, type(uint96).max); // Ensure _amount is between 1e18 and uint96 max value
        uint256 convertRatio = 1e18;
        // enqueue assetAmount/convertRatio iUSD to the queue
        uint256 iUSDAmount = _assetAmount * 1e18 / convertRatio;
        _enqueue(RECIPIENT, iUSDAmount);

        // fund the queue with same amount of asset to redeem 100 iUSD
        (uint256 remainingAssets, uint256 receiptAmountToBurn) = _fundRedemptionQueue(_assetAmount, convertRatio);
        assertEq(remainingAssets, 0, "Error: remainingAssets should be 0");
        assertEq(receiptAmountToBurn, iUSDAmount, "Error: receiptAmountToBurn should be equal to the amount enqueued");
        assertEq(queue.length(), 0, "Error: queue should be empty");
    }

    /// @notice test the fundRedemptionQueue function when the queue has more redemptions than the funding amount
    /// the fundRedemptionQueue function should return the remaining assets and the receipt amount to burn
    /// the remaining assets should be 0
    /// the receipt amount to burn should be the difference between the amount enqueued and the funding amount
    function testFundRedemptionQueuePartialAmount() public {
        uint256 _assetAmount = 100e18; // fund with 100 USDC
        uint256 convertRatio = 1e18;
        // enqueue assetAmount/convertRatio iUSD to the queue
        uint256 iUSDAmount = 233e18; // a user wants to redeem 233 iUSD
        address recipient = RECIPIENT;
        _enqueue(recipient, iUSDAmount);

        uint256 expectedReceiptAmountToBurn = 100e18; // this works because convertRatio is 1e18
        uint256 expectedRemainingInRedemptionRequest = 133e18; // this works because convertRatio is 1e18

        // fund the queue with same amount of asset to redeem 100 iUSD
        (uint256 remainingAssets, uint256 receiptAmountToBurn) = _fundRedemptionQueue(_assetAmount, convertRatio);
        assertEq(remainingAssets, 0, "Error: remainingAssets should be 0");
        assertEq(
            receiptAmountToBurn,
            expectedReceiptAmountToBurn,
            "Error: receiptAmountToBurn should be equal to the amount enqueued"
        );
        assertEq(queue.length(), 1, "Error: queue should have one request");
        RedemptionQueue.RedemptionRequest memory request = queue.front();
        assertEq(request.recipient, recipient, "Error: recipient is not set correctly in request");
        assertEq(request.amount, expectedRemainingInRedemptionRequest, "Error: amount is not set correctly in request");
        assertEq(totalPendingClaims, _assetAmount, "Error: totalPendingClaims should be equal to the funding amount");
        assertEq(
            totalEnqueuedRedemptions,
            expectedRemainingInRedemptionRequest,
            "Error: totalEnqueuedRedemptions should be 133e18"
        );
        assertEq(userPendingClaims[recipient], 100e18, "Error: userPendingClaims should be 100e18");

        // fullfill the redemption
        _claimRedemption(recipient);
        assertEq(totalPendingClaims, 0, "totalPendingClaims should be 0");
        assertEq(userPendingClaims[recipient], 0, "userPendingClaims should be 0");
    }

    /// @notice test the case where the convert ratio is not 1
    /// meaning that 1 iUSD is redeemed for less than 1 USDC for example 0.8 USDC
    /// in this case, the funding amount is 100 USDC and we have 100 iUSD enqueued
    /// if the ratio was 1, we should burn 100 iUSD and the remaining assets should be 0
    /// but since the ratio is 0.8, it will take only 80 USDC to fund the 100 iUSD redemption
    /// meaning that 20 USDC will be left (remainingAssets) and we will burn 100 iUSD
    /// and the queue should be empty after that
    function testFundRedemptionQueueWithRatioNot1() public {
        uint256 _assetAmount = 100e18; // fund with 100 USDC
        uint256 convertRatio = 0.8e18; // here 1 iUSD = 0.8 USDC
        // enqueue assetAmount/convertRatio iUSD to the queue
        uint256 iUSDAmount = 100e18; // a user wants to redeem 100 iUSD
        address recipient = RECIPIENT;
        _enqueue(recipient, iUSDAmount);

        // fund the queue with same amount of asset to redeem 100 iUSD
        (uint256 remainingAssets, uint256 receiptAmountToBurn) = _fundRedemptionQueue(_assetAmount, convertRatio);
        assertEq(remainingAssets, 20e18, "Error: remainingAssets should be 20e18");
        assertEq(receiptAmountToBurn, 100e18, "Error: receiptAmountToBurn should be 100e18");
        assertTrue(queue.empty(), "Error: queue should be empty");

        assertEq(totalPendingClaims, 80e18, "Error: totalPendingClaims should be 80e18");
        assertEq(totalEnqueuedRedemptions, 0, "Error: totalEnqueuedRedemptions should be 0");
        assertEq(userPendingClaims[recipient], 80e18, "Error: userPendingClaims should be 80e18");

        // fullfill the redemption
        _claimRedemption(recipient);
        assertEq(totalPendingClaims, 0, "Error: totalPendingClaims should be 0");
        assertEq(userPendingClaims[recipient], 0, "Error: userPendingClaims should be 0");
    }

    /// @notice test scenarios with fuzzing amount of funding and enqueued amount, also fuzzing the number of redemptions (tickets) in the queue
    /// this test is done to ensure that the fundRedemptionQueue function works as expected in both following cases:
    /// - we have more (or equal) funding than the total enqueued amount
    /// - we have less funding than the total enqueued amount
    function testFundWithManyTickets(uint256 _fundingAmount, uint256 _totalEnqueuedAmount, uint256 _redemptionCount)
        public
    {
        _fundingAmount = bound(_fundingAmount, 1000e18, type(uint128).max);
        _totalEnqueuedAmount = bound(_totalEnqueuedAmount, 1000e18, 10 * uint256(type(uint96).max));
        // generate a random number of redemptions between 11 and 100
        // 11 lower bound is because the _totalEnqueuedAmount higher bound is 10 * uint96.max
        // so we want to have at least 11 redemptions so that each can fit in a uint96
        _redemptionCount = bound(_redemptionCount, 11, 100);

        _setUpFundWithManyTickets(_totalEnqueuedAmount, _redemptionCount);

        // fund the queue with the funding amount
        uint256 convertRatio = 1e18;
        (uint256 remainingAssets, uint256 receiptAmountToBurn) = _fundRedemptionQueue(_fundingAmount, convertRatio);

        // all the following assertions are based on the fact that the convert ratio is 1:1
        if (_fundingAmount >= _totalEnqueuedAmount) {
            // case where we have more (or equal) funding than the total enqueued amount
            assertEq(
                remainingAssets,
                _fundingAmount - _totalEnqueuedAmount,
                "Error: remainingAssets should be difference between fundingAmount and enqueuedAmount"
            );
            assertEq(
                totalPendingClaims,
                _totalEnqueuedAmount,
                "Error: totalPendingClaims should be equals to the enqueued amount"
            );
            assertEq(receiptAmountToBurn, _totalEnqueuedAmount, "Error: Should burn all receipt token in the queue");
            assertEq(queue.length(), 0, "Error: Queue should be empty");
            assertEq(totalEnqueuedRedemptions, 0, "Error: totalEnqueuedRedemptions should be 0");
        } else {
            // case where we have less funding than the total enqueued amount
            assertEq(remainingAssets, 0, "Error: remainingAssets should be 0");
            assertEq(totalPendingClaims, _fundingAmount, "Error: Should have funded _fundingAmount assets (USDC)");
            assertEq(
                receiptAmountToBurn, _fundingAmount, "Error: Should burn fundingAmount receipt tokens from the queue"
            );
            assertGt(queue.length(), 0, "Error: Queue should not be empty");
            assertGt(totalEnqueuedRedemptions, 0, "Error: totalEnqueuedRedemptions should be greater than 0");
        }
    }
}
