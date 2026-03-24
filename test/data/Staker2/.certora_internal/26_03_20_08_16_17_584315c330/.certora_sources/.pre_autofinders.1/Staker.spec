methods {
    function _.balanceOf(address addr) external envfree;
}

rule stakeAUnstakeA(env e) {
    require(e.msg.sender != currentContract);
    require(currentContract.receipts.balanceOf(e, e.msg.sender) == 0);

    uint256 assetsBefore = currentContract.assets.balanceOf(e, e.msg.sender);

    uint256 assetAmountA;
    stakeA(e, assetAmountA);

    uint256 assetAmountB;
    unstakeA(e, assetAmountB);

    uint256 assetsAfter = currentContract.assets.balanceOf(e, e.msg.sender);

    assert(assetsAfter <= assetsBefore);
}

rule stakeBUnstakeB(env e) {
    require(e.msg.sender != currentContract);
    require(currentContract.receipts.balanceOf(e, e.msg.sender) == 0);

    uint256 assetsBefore = currentContract.assets.balanceOf(e, e.msg.sender);

    uint256 assetAmountA;
    stakeB(e, assetAmountA);

    uint256 assetAmountB;
    unstakeB(e, assetAmountB);

    uint256 assetsAfter = currentContract.assets.balanceOf(e, e.msg.sender);

    assert(assetsAfter <= assetsBefore);
}

rule stakeAWithdrawA(env e) {
    require(e.msg.sender != currentContract);
    require(currentContract.receipts.balanceOf(e, e.msg.sender) == 0);

    uint256 assetsBefore = currentContract.assets.balanceOf(e, e.msg.sender);

    uint256 assetAmount;
    stakeA(e, assetAmount);

    uint256 receiptAmount;
    withdrawA(e, receiptAmount);

    uint256 assetsAfter = currentContract.assets.balanceOf(e, e.msg.sender);

    assert(assetsAfter <= assetsBefore);
}

rule stakeBWithdrawB(env e) {
    require(e.msg.sender != currentContract);
    require(currentContract.receipts.balanceOf(e, e.msg.sender) == 0);

    uint256 assetsBefore = currentContract.assets.balanceOf(e, e.msg.sender);

    uint256 assetAmount;
    stakeB(e, assetAmount);

    uint256 receiptAmount;
    withdrawB(e, receiptAmount);

    uint256 assetsAfter = currentContract.assets.balanceOf(e, e.msg.sender);

    assert(assetsAfter <= assetsBefore);
}
