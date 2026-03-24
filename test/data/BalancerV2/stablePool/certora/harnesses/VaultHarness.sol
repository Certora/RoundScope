pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "../munged/vault/contracts/Vault.sol";

contract VaultHarness is Vault {
    constructor(IAuthorizer authorizer, IWETH weth, uint256 pauseWindowDuration, uint256 bufferPeriodDuration) 
        Vault(authorizer, weth, pauseWindowDuration, bufferPeriodDuration) {
    }

    bytes data;

    function Harness_doubleJoinPool(bytes32 poolId, address sender, address payable recipient, IAsset token_a, IAsset token_b, 
                                     uint256 maxAmountInA, uint256 maxAmountInB, bool fromInternalBalance) public {

        IAsset[] memory tokens_array = new IAsset[](2);
        tokens_array[0] = token_a;
        tokens_array[1] = token_b;

        uint256[] memory amounts_array = new uint256[](2);
        amounts_array[0] = maxAmountInA;
        amounts_array[1] = maxAmountInB;

        JoinPoolRequest memory req = JoinPoolRequest(tokens_array, amounts_array, data, fromInternalBalance);
        this.joinPool(poolId, sender, recipient, req);
    }


    function Harness_doubleExitPool(bytes32 poolId, address sender, address payable recipient, IAsset token_a, 
                                    IAsset token_b, uint256 minAmountOutA, uint256 minAmountOutB, 
                                    bool toInternalBalance) public {
        IAsset[] memory tokens_array = new IAsset[](2);
        tokens_array[0] = token_a;
        tokens_array[1] = token_b;

        uint256[] memory amounts_array = new uint256[](2);
        amounts_array[0] = minAmountOutA;
        amounts_array[1] = minAmountOutB;

        ExitPoolRequest memory req = ExitPoolRequest(tokens_array, amounts_array, data, toInternalBalance);
        this.exitPool(poolId, sender, recipient, req);
    }


}