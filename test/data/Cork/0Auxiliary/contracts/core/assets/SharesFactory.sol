// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {BokkyPooBahsDateTimeLibrary} from "BokkyPooBahsDateTimeLibrary/BokkyPooBahsDateTimeLibrary.sol";
import {IPoolShare, PoolShare} from "contracts/core/assets/PoolShare.sol";
import {ISharesFactory} from "contracts/interfaces/ISharesFactory.sol";

//             CCCCCCCCC  C
//          CCCCCCCCCCC   C
//       CCCCCCCCCCCCCC   C
//     CCCCCCCCCCCCCCCC   C        CCCCCC                    CCCCCCCCCCCCCCC             CCCCCCCCCCCCCCC     CCCCCCCCCCCCCCCCCCCC     CCCCCCCCCCC     CCCCCCCCCC
//    CCCCCCCCCCCCCCCCC CC       CCCCCC  C               CCCCCCCCCCCCCCCCCC  CCC     CCCCCCCCCCCCCCCCCC  CC  CCCCCCCCCCCCCCCCCCCC  CC CCCCCCC   C    CCCCCCCC  CC
//   CCCCCCCCCCCCCCCC CC       CCCCCCCCC  C            CCCCCCCCCCCCCCCCCCCCC    CC CCCCCCCCCCCCCCCCCCCCCC   CCCCCCCCCCCCCCCCCCCCCCC  CCCCCCCC   C    CCCCCCCC  CC
//  CCCCCCCCCCCCCCC CC        CCCCCCCCCCC  C          CCCCCCCCCCCCCCCCCCCCCCCC    CCCCCCCCCCCCCCCCCCCCCCCC   CCCCCCCCCCCCCCCCCCCCCCC  CCCCCCC   C  CCCCCCCCCC  CC
// CCCCCCCCCCCCCC CC        CCCCCCCCCCCCC  CC        CCCCCCCCC    CC  CCCCCCCCC  CCCCCCCCC   CC   CCCCCCCCC  CCCCCCC    C   CCCCCCCC  CCCCCCC   CCCCCCCCCCC  CC
// CCCCCCCCCCCC  C         CCCCCCCCCCCCCCC  C        CCCCCCCC    CC     CCCCCCCCCCCCCCCC    CC     CCCCCCCC  CCCCCCC    C    CCCCCCC  CCCCCCC  CCCCCCCCCC  CC
// CCCCCCCCCCCC  C         CCCCCCCCCCCCCCC  C       CCCCCCCC    CC              CCCCCCCC   CC       CCCCCCCC CCCCCCC    C   CCCCCCCC  CCCCCCC  CCCCCCCC   C
// CCCCCCCCCCCC  C         CCCCCCCCCCCCCCC   C      CCCCCCCC    C               CCCCCCCC   C        CCCCCCCC CCCCCCCCCCCCCCCCCCCCCCC  CCCCCCC  CCCCCCCC   C
// CCCCCCCCCCCC  C         CCCCCCCCCCCCCCC  C       CCCCCCCC    CC              CCCCCCCC   CC       CCCCCCCC CCCCCCCCCCCCCCCCCCCCC   CCCCCCCC  CCCCCCCC   CC
// CCCCCCCCCCCC  C         CCCCCCCCCCCCCCC  C        CCCCCCCC    CC     CCCCCCCCCCCCCCCC    CC     CCCCCCCC  CCCCCCCCCCCCCCCCCCC   CC CCCCCCC  CCCCCCCCCC   C
// CCCCCCCCCCCCCC CC        CCCCCCCCCCCCC  CC        CCCCCCCCC    CCC CCCCCCCCC  CCCCCCCCC   CCC  CCCCCCCCC  CCCCCCCCCCCCCCCCCCCCC   CCCCCCCC   CCCCCCCCCCC  CC
//  CCCCCCCCCCCCCCC CC        CCCCCCCCCCC  C          CCCCCCCCCCCCCCCCCCCCCCCC   CCCCCCCCCCCCCCCCCCCCCCCCC   CCCCCCC    C CCCCCCCCCC  CCCCCCC   C  CCCCCCCCCC  CC
//   CCCCCCCCCCCCCCCC CC        CCCCCCCC  C            CCCCCCCCCCCCCCCCCCCCC    CC CCCCCCCCCCCCCCCCCCCCCC  CCCCCCCCC    C   CCCCCCCC  CCCCCCC   C    CCCCCCCC  CC
//    CCCCCCCCCCCCCCCC  CC        CCCCC CC                CCCCCCCCCCCCCCCC   CC      CCCCCCCCCCCCCCCCC  CCC  CCCCCCC    C   CCCCCCCC  CCCCCCC   C    CCCCCCCC  CC
//     CCCCCCCCCCCCCCCC   C        CCCCCC                    CCCCCCCCCCCCCCC             CCCCCCCCCCCCCC      CCCCCCCCCCCC    CCCCCCCCCCCCCCCCCCCC     CCCCCCCCCC
//       CCCCCCCCCCCCCC   C
//          CCCCCCCCCCC   C
//              CCCCCCCCCCC

/// @title SharesFactory
/// @author Cork Team
/// @custom:security-contact security@cork.tech
/// @notice Factory contract for deploying ERC20 PoolShares contracts (cST and cPT tokens).
contract SharesFactory is ISharesFactory, Ownable {
    string private constant CPT_SUFFIX = "cPT";
    string private constant CST_SUFFIX = "cST";

    // slither-disable-next-line naming-convention
    address public immutable CORK_POOL_MANAGER;

    modifier onlyCorkPoolManager() {
        require(CORK_POOL_MANAGER == msg.sender, NotCorkPoolManager());
        _;
    }

    ///======================================================///
    ///============== INITIALIZATION FUNCTIONS ==============///
    ///======================================================///

    constructor(address corkPoolManager, address ensOwner) Ownable(ensOwner) {
        require(corkPoolManager != address(0), ZeroAddress());
        CORK_POOL_MANAGER = corkPoolManager;
    }

    ///======================================================///
    ///================== CORE FUNCTIONS ====================///
    ///======================================================///

    /// @inheritdoc ISharesFactory
    function deployPoolShares(DeployParams calldata params)
        external
        override
        onlyCorkPoolManager
        returns (address principalToken, address swapToken)
    {
        // slither-disable-next-line write-after-write
        (string memory name, string memory symbol) = _generateSymbolWithVariant(
            params.poolParams.collateralAsset,
            params.poolParams.referenceAsset,
            params.poolParams.expiryTimestamp,
            CPT_SUFFIX
        );

        address ensOwner = owner();
        IPoolShare.ConstructorParams memory constructorParams =
            IPoolShare.ConstructorParams(params.poolId, name, symbol, CORK_POOL_MANAGER, ensOwner);

        principalToken = address(new PoolShare(constructorParams));

        // slither-disable-next-line write-after-write
        (name, symbol) = _generateSymbolWithVariant(
            params.poolParams.collateralAsset,
            params.poolParams.referenceAsset,
            params.poolParams.expiryTimestamp,
            CST_SUFFIX
        );
        constructorParams.pairName = name;
        constructorParams.symbol = symbol;

        swapToken = address(new PoolShare(constructorParams));

        emit SharesDeployed(params.poolParams.collateralAsset, principalToken, swapToken);
    }

    ///======================================================///
    ///================= INTERNAL FUNCTIONS =================///
    ///======================================================///

    /// @dev will generate symbol such as wstETH03cPT.
    /// @param collateralAsset The address of the Collateral Asset token.
    /// @param referenceAsset The address of the Reference Asset token.
    /// @param expiry The expiry date in Unix timestamp format.
    /// @param suffix The suffix to be added to the symbol.
    /// @return name The generated name with the variant.
    /// @return symbol The generated symbol with the variant.
    function _generateSymbolWithVariant(
        address collateralAsset,
        address referenceAsset,
        uint256 expiry,
        string memory suffix
    ) internal view returns (string memory name, string memory symbol) {
        string memory referenceSymbol = IERC20Metadata(referenceAsset).symbol();
        string memory month = Strings.toString(BokkyPooBahsDateTimeLibrary.getMonth(expiry));

        name = string.concat(IERC20Metadata(collateralAsset).symbol(), "-", referenceSymbol, month, suffix);
        symbol = string.concat(referenceSymbol, month, suffix);
    }
}
