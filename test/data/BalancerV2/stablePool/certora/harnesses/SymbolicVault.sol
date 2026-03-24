pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@balancer-labs/v2-solidity-utils/contracts/math/Math.sol";
import "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";

contract SymbolicVault {
    using Math for uint256;


    //Store the balanceof from each token to account 
    mapping (IERC20  => mapping (address => uint)) public balanceOf;
    mapping (bytes32 => IERC20[]) public poolTokens;
    mapping (bytes32 => mapping (IERC20  => uint256)) public tokenCash;
    mapping (bytes32 => mapping (IERC20  => uint256)) public tokenManaged;
    mapping (bytes32 => mapping (IERC20  => uint256)) public tokenLastChangeBlock;
    mapping (bytes32 => mapping (IERC20  => address)) public tokenAssetManager;

    enum UserBalanceOpKind { DEPOSIT_INTERNAL, WITHDRAW_INTERNAL, TRANSFER_INTERNAL, TRANSFER_EXTERNAL }
    
    struct UserBalanceOp {
        UserBalanceOpKind kind;
        IERC20 asset;
        uint256 amount;
        address sender;
        address payable recipient;
    }

    function manageUserBalance(UserBalanceOp[] memory ops) external payable {
    	for(uint256 i; i < ops.length ; i++) {

    		uint256 amount =  ops[i].amount;

            address recipient = ops[i].recipient;
            address sender = ops[i].sender;
            IERC20 asset = ops[i].asset;

    		if (ops[i].kind ==  UserBalanceOpKind.DEPOSIT_INTERNAL) {
    			IERC20(asset).transferFrom(sender, address(this), amount);
    			balanceOf[asset][recipient] = balanceOf[asset][recipient].add(amount);
    		}
    		else if (ops[i].kind ==  UserBalanceOpKind.WITHDRAW_INTERNAL) {
    			IERC20(asset).transfer(recipient, amount);
    			balanceOf[asset][sender] = balanceOf[asset][sender].sub(amount);
    		}
    		else if  (ops[i].kind ==  UserBalanceOpKind.TRANSFER_INTERNAL) {
    			balanceOf[asset][sender] = balanceOf[asset][sender].sub(amount);
    			balanceOf[asset][recipient] = balanceOf[asset][recipient].add(amount);
    		}
    		else if (ops[i].kind ==  UserBalanceOpKind.TRANSFER_EXTERNAL) {
    			IERC20(asset).transferFrom(sender, address(this), amount);
                IERC20(asset).transfer(recipient, amount);	
    		}
    	}
    }

    function totalAssetsOfUser(IERC20 asset, address user) external view returns (uint256){
        return asset.balanceOf(user).add(balanceOf[asset][user]);
    }

    function getPoolTokenInfo(bytes32 poolId, IERC20 token) external view returns 
        (uint256 cash, uint256 managed, uint256 lastChangeBlock, address assetManager) {
        return (
            tokenCash[poolId][token],
            tokenManaged[poolId][token],
            tokenLastChangeBlock[poolId][token],
            tokenAssetManager[poolId][token]
        );
    }

    function getPoolTokens(bytes32 poolId) external view returns (IERC20[] memory tokens, uint256[] memory balances) {
        tokens = poolTokens[poolId];
        for (uint256 i; i < tokens.length; i++) {
            balances[i] = tokenCash[poolId][tokens[i]];
        }
    }
}