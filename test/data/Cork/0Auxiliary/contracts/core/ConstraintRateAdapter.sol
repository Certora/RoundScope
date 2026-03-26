// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IConstraintRateAdapter} from "contracts/interfaces/IConstraintRateAdapter.sol";
import {IPoolManager, Market, MarketId} from "contracts/interfaces/IPoolManager.sol";
import {IComposableRateOracle} from "contracts/interfaces/IRateOracle.sol";
import {TransferHelper} from "contracts/libraries/TransferHelper.sol";

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

/// @title ConstraintRateAdapters
/// @author Cork Team
/// @custom:security-contact security@cork.tech
/// @notice Contract for managing oracle rate constraints.
contract ConstraintRateAdapter is
    IConstraintRateAdapter,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    struct ConstraintRateAdapterStorage {
        address CORK_POOL_MANAGER;
        mapping(MarketId => ConstraintState) constraints;
    }

    // ERC-7201 Namespaced Storage Layout.
    // keccak256(abi.encode(uint256(keccak256("cork.storage.ConstraintRateAdapter")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant _CONSTRAINT_ADAPTER_STORAGE_POSITION =
        0xf88cefad790528de4ec7608c6ea34edd21e78fe1868b343ccaa1ae3a22fa9c00;

    ///======================================================///
    ///=================== MODIFIERS ========================///
    ///======================================================///

    modifier onlyCorkPoolManager() {
        require(_msgSender() == data().CORK_POOL_MANAGER, NotCorkPoolManager());
        _;
    }

    ///======================================================///
    ///============== INITIALIZATION FUNCTIONS ==============///
    ///======================================================///

    constructor() {
        _disableInitializers();
    }

    function initialize(address ensOwner, address upgradeAdmin) external initializer {
        require(ensOwner != address(0) && upgradeAdmin != address(0), InvalidAddress());
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Ownable_init(ensOwner);

        _grantRole(DEFAULT_ADMIN_ROLE, upgradeAdmin);
    }

    /// @dev Set the Cork Pool Manager contract address.
    /// Only callable by the DEFAULT_ADMIN_ROLE.
    /// Definition is only allowed once.
    /// @param corkPoolManager The address of the Cork Pool Manager contract.
    function setOnceCorkPoolManager(address corkPoolManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(corkPoolManager != address(0), ZeroAddress());
        require(data().CORK_POOL_MANAGER == address(0), AlreadySet());
        data().CORK_POOL_MANAGER = corkPoolManager;
    }

    ///======================================================///
    ///================== CORE FUNCTIONS ====================///
    ///======================================================///

    /// @inheritdoc IConstraintRateAdapter
    function bootstrap(MarketId poolId) external onlyCorkPoolManager {
        Market memory pool = IPoolManager(data().CORK_POOL_MANAGER).market(poolId);
        ConstraintState storage constraint = data().constraints[poolId];

        uint256 rate = _fetchRate(pool);

        require(rate >= pool.rateMin, InvalidRate());
        require(rate <= pool.rateMax, InvalidRate());

        constraint._lastAdjustedRate = rate;
        constraint._lastAdjustmentTimestamp = block.timestamp;
        constraint._remainingCredits = pool.rateChangeCapacityMax;
    }

    /// @inheritdoc IConstraintRateAdapter
    function adjustedRate(MarketId poolId) external onlyCorkPoolManager returns (uint256 rate) {
        Market memory pool = IPoolManager(data().CORK_POOL_MANAGER).market(poolId);
        ConstraintState storage constraint = data().constraints[poolId];

        uint256 newRate = _fetchRate(pool);

        uint256 remainingCreditsResult;
        bool updated;
        (rate, remainingCreditsResult, updated) = _calculateRate(
            RateCalculationParams(
                newRate,
                constraint._lastAdjustedRate,
                constraint._remainingCredits,
                constraint._lastAdjustmentTimestamp,
                block.timestamp,
                pool.rateChangePerDayMax,
                pool.rateChangeCapacityMax,
                pool.rateMin,
                pool.rateMax
            )
        );

        // Only update last adjustment timestamp if there's an actual rate change.
        if (updated) constraint._lastAdjustmentTimestamp = block.timestamp;
        constraint._lastAdjustedRate = rate;
        constraint._remainingCredits = remainingCreditsResult;
    }

    ///======================================================///
    ///================== VIEW FUNCTIONS ====================///
    ///======================================================///

    /// @inheritdoc IConstraintRateAdapter
    // slither-disable-next-line naming-convention
    function CORK_POOL_MANAGER() external view returns (address corkPoolManager) {
        corkPoolManager = data().CORK_POOL_MANAGER;
    }

    /// @inheritdoc IConstraintRateAdapter
    function previewAdjustedRate(MarketId poolId) external view onlyCorkPoolManager returns (uint256 rate) {
        Market memory pool = IPoolManager(data().CORK_POOL_MANAGER).market(poolId);
        ConstraintState storage constraint = data().constraints[poolId];

        uint256 newRate = _fetchRate(pool);

        (rate,,) = _calculateRate(
            RateCalculationParams(
                newRate,
                constraint._lastAdjustedRate,
                constraint._remainingCredits,
                constraint._lastAdjustmentTimestamp,
                block.timestamp,
                pool.rateChangePerDayMax,
                pool.rateChangeCapacityMax,
                pool.rateMin,
                pool.rateMax
            )
        );
    }

    /// @inheritdoc IConstraintRateAdapter
    function constraints(MarketId poolId) external view returns (uint256, uint256, uint256) {
        ConstraintState memory constraint = data().constraints[poolId];
        return (constraint._lastAdjustedRate, constraint._lastAdjustmentTimestamp, constraint._remainingCredits);
    }

    ///======================================================///
    ///================= INTERNAL FUNCTIONS =================///
    ///======================================================///

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    function data() internal pure returns (ConstraintRateAdapterStorage storage cs) {
        // slither-disable-next-line assembly
        assembly {
            cs.slot := _CONSTRAINT_ADAPTER_STORAGE_POSITION
        }
    }

    function _fetchRate(Market memory pool) internal view returns (uint256 rate) {
        return IComposableRateOracle(pool.rateOracle).rate();
    }

    // Slither complains that we use a block.timestamp comparison here which we don't.
    // slither-disable-start timestamp
    function _calculateRate(RateCalculationParams memory params)
        internal
        pure
        returns (uint256 rate, uint256 remainingCreditsResult, bool updated)
    {
        int256 rateChangeIncoming = int256(params.newRate) - int256(params.lastAdjustedRate);

        // To prevent unnecessary math being done if there's no change in the rate.
        // slither-disable-next-line incorrect-equality
        if (rateChangeIncoming == 0) return (params.lastAdjustedRate, params.remainingCredits, false);

        // Mark as updated since there's some rate diff.
        updated = true;

        // Keep full precision by multiplying with 1e18.
        uint256 refillRatePerSeconds = Math.mulDiv(params.rateChangePerDayMax, 1e18, 1 days);

        // refillRatePerSeconds is scaled by 1e18, we need to div down this operation by 1e18.
        // as we won't need the extra precision since it's just sub and add after this.
        uint256 creditsRefilled =
            Math.mulDiv(params.currentTimestamp - params.lastAdjustmentTimestamp, refillRatePerSeconds, 1e18);

        uint256 creditsCapped = params.rateChangeCapacityMax < params.remainingCredits + creditsRefilled
            ? params.rateChangeCapacityMax
            : params.remainingCredits + creditsRefilled;

        // Casting to 'uint256' is safe because we multiply by -1 if rateChangeIncoming is negative.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint256 rateChangeIncomingAbs =
            rateChangeIncoming > 0 ? uint256(rateChangeIncoming) : uint256(-rateChangeIncoming);
        uint256 creditsConsumed = rateChangeIncomingAbs < creditsCapped ? rateChangeIncomingAbs : creditsCapped;

        // We're going to double calculate the rate, if the first calculation goes below/above min/max rate, we're going to clamp it down/up.
        // and recalculate what the actual rate change and credits consumed are.

        // First calculation, may go below/above the min/max rate.
        rate = rateChangeIncoming > 0
            ? params.lastAdjustedRate + creditsConsumed
            : params.lastAdjustedRate - creditsConsumed;

        // Clamp rate to min/max bounds.
        if (rate < params.rateMin) rate = params.rateMin;
        else if (rate > params.rateMax) rate = params.rateMax;

        // Calculate actual credits consumed based on the actual rate change.
        uint256 actualRateChange =
            rate > params.lastAdjustedRate ? rate - params.lastAdjustedRate : params.lastAdjustedRate - rate;
        uint256 actualCreditsConsumed = actualRateChange;

        remainingCreditsResult = creditsCapped - actualCreditsConsumed;
    }
    // slither-disable-end timestamp
}
