// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.30;

import {IMorphoChainlinkOracleV2} from "@morpho-oracle/interfaces/IMorphoChainlinkOracleV2.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IRateOracle} from "contracts/interfaces/IRateOracle.sol";

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

/// @title WrapperRateConsumer
/// @author Cork Team
/// @custom:security-contact security@cork.tech
/// @notice Wrapper for Morpho MorphoChainlinkOracleV2 that normalizes the price to Cork's 18-decimal rate format.
contract WrapperRateConsumer is IRateOracle {
    /// @notice The underlying Morpho oracle
    IMorphoChainlinkOracleV2 public immutable MORPHO_ORACLE;

    /// @dev Morpho-compatible oracle returns price with precision: 36 + QUOTE_DECIMALS - BASE_DECIMALS
    /// We need to normalize this to exactly 36 decimals, then divide by 1e18 since Cork expects 18-decimal rate.
    ///
    /// If QUOTE_DECIMALS > BASE_DECIMALS:
    /// - Oracle returns MORE than 36 decimals (e.g., 36+18-6 = 48 decimals)
    /// - Divide by 10^(QUOTE_DECIMALS - BASE_DECIMALS) to reduce to 36 decimals
    ///
    /// If BASE_DECIMALS > QUOTE_DECIMALS:
    /// - Oracle returns LESS than 36 decimals (e.g., 36+6-18 = 24 decimals)
    /// - Multiply by 10^(BASE_DECIMALS - QUOTE_DECIMALS) to increase to 36 decimals
    ///
    /// If equal: already at 36 decimals, use as-is
    ///
    /// And then divide by 1e18 to get Cork 18-decimal rate format
    uint256 public immutable BASE_DECIMALS;
    uint256 public immutable QUOTE_DECIMALS;

    /// @notice Constructor
    /// @param _morphoOracle Address of oracle that's compatible with MorphoChainlinkOracleV2
    /// @param _baseTokenDecimals Decimals of the base token (collateral in Morpho terms)
    /// @param _quoteTokenDecimals Decimals of the quote token (loan in Morpho terms)
    constructor(address _morphoOracle, uint256 _baseTokenDecimals, uint256 _quoteTokenDecimals) {
        require(_morphoOracle != address(0), ZeroAddress());

        MORPHO_ORACLE = IMorphoChainlinkOracleV2(_morphoOracle);

        QUOTE_DECIMALS = address(MORPHO_ORACLE.QUOTE_VAULT()) != address(0)
            ? IERC4626(address(MORPHO_ORACLE.QUOTE_VAULT())).decimals()
            : _quoteTokenDecimals;
        BASE_DECIMALS = address(MORPHO_ORACLE.BASE_VAULT()) != address(0)
            ? IERC4626(address(MORPHO_ORACLE.BASE_VAULT())).decimals()
            : _baseTokenDecimals;

        require(_rate() > 0, InvalidRate());
    }

    function _rate() internal view returns (uint256) {
        uint256 morphoPrice = MORPHO_ORACLE.price();

        // Apply normalization to get price in pure 36 decimals
        uint256 normalizedPrice;
        if (QUOTE_DECIMALS > BASE_DECIMALS) {
            normalizedPrice = morphoPrice / 10 ** (QUOTE_DECIMALS - BASE_DECIMALS);
        } else if (BASE_DECIMALS > QUOTE_DECIMALS) {
            normalizedPrice = morphoPrice * 10 ** (BASE_DECIMALS - QUOTE_DECIMALS);
        } else {
            normalizedPrice = morphoPrice;
        }

        // Divide by 1e18 to get 18-decimal rate
        normalizedPrice = normalizedPrice / 1 ether;

        return normalizedPrice;
    }

    /// @inheritdoc IRateOracle
    /// @notice Returns the normalized rate in 18 decimals
    /// @dev Applies normalization to convert Morpho's price to Cork's rate format
    function rate() external view returns (uint256) {
        return _rate();
    }
}
