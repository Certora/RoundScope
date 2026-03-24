// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.7.0;

import "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";
import "@balancer-labs/v2-solidity-utils/contracts/math/Math.sol";

// These functions start with an underscore, as if they were part of a contract and not a library. At some point this
// should be fixed. Additionally, some variables have non mixed case names (e.g. P_D) that relate to the mathematical
// derivations.
// solhint-disable private-vars-leading-underscore, var-name-mixedcase

contract StableMath {
    using FixedPoint for uint256;

    uint256 internal constant _MIN_AMP = 1;
    uint256 internal constant _MAX_AMP = 5000;
    uint256 internal constant _AMP_PRECISION = 1e3;

    uint256 internal constant _MAX_STABLE_TOKENS = 5;

    bool internal _called;

    constructor() {
        _called = false;
    }

    function beenCalled() public view returns(bool) {
        return _called;
    }

    function resetCalled() public {
        _called = false;
    }


    function _calculateInvariant(uint256 amplificationParameter, uint256[] memory balances)
        public
        returns (uint256)
    {
        uint256 value;
        _called = true;
        return value;
    }

    function _calcOutGivenIn(
        uint256 amplificationParameter,
        uint256[] memory balances,
        uint256 tokenIndexIn,
        uint256 tokenIndexOut,
        uint256 tokenAmountIn,
        uint256 invariant
    ) public returns (uint256) {
        _called = true;
        uint256 value;
        if (tokenAmountIn > 0) { require (value > 0);}
        else require (value == 0);
        return value;
    }

    function _calcInGivenOut(
        uint256 amplificationParameter,
        uint256[] memory balances,
        uint256 tokenIndexIn,
        uint256 tokenIndexOut,
        uint256 tokenAmountOut,
        uint256 invariant
    ) public returns (uint256) {
        _called = true;
        uint256 value;
        if (tokenAmountOut > 0) { require (value > 0);}
        else require (value == 0);
        return value;    
    }

    function _calcBptOutGivenExactTokensIn(
        uint256 amp,
        uint256[] memory balances,
        uint256[] memory amountsIn,
        uint256 bptTotalSupply,
        uint256 swapFeePercentage
    ) public returns (uint256) {
        _called = true;
        uint256 value;
        uint256 input;
        for (uint256 i=0;i<amountsIn.length;++i) {
            input += amountsIn[i];
        }
        if (input > 0) { require (value > 0);}
        else require (value==0);
        return value;
    }

    function _calcTokenInGivenExactBptOut(
        uint256 amp,
        uint256[] memory balances,
        uint256 tokenIndex,
        uint256 bptAmountOut,
        uint256 bptTotalSupply,
        uint256 swapFeePercentage
    ) public returns (uint256) {        
        _called = true;
        uint256 value;
        if (bptAmountOut > 0) { require (value > 0);}
        else require (value == 0);
        return value;
    }

    function _calcBptInGivenExactTokensOut(
        uint256 amp,
        uint256[] memory balances,
        uint256[] memory amountsOut,
        uint256 bptTotalSupply,
        uint256 swapFeePercentage
    ) public returns (uint256) {
        _called = true;
        uint256 value;
        uint256 input;
        for (uint256 i=0;i<amountsOut.length;++i) {
            input += amountsOut[i];
        }
        if (input > 0) { require (value > 0);}
        else require (value == 0);
        return value;
    }

    function _calcTokenOutGivenExactBptIn(
        uint256 amp,
        uint256[] memory balances,
        uint256 tokenIndex,
        uint256 bptAmountIn,
        uint256 bptTotalSupply,
        uint256 swapFeePercentage
    ) public returns (uint256) {
        _called = true;
        uint256 value;
        if (bptAmountIn > 0) { require (value > 0);}
        else require (value == 0);
        return value;
    }

    function _calcTokensOutGivenExactBptIn(
        uint256[] memory balances,
        uint256 bptAmountIn,
        uint256 bptTotalSupply
    ) public returns (uint256[] memory) {
        _called = true;
        uint256[] memory values;
        uint256 output;
        for (uint256 i=0;i<balances.length;++i) {
            output += values[i];
        }        
        if (bptAmountIn > 0) { require (output > 0);}
        else require (output == 0);
        return values;
    }

    function _calcDueTokenProtocolSwapFeeAmount(
        uint256 amplificationParameter,
        uint256[] memory balances,
        uint256 lastInvariant,
        uint256 tokenIndex,
        uint256 protocolSwapFeePercentage
    ) public returns (uint256) {
        uint256 value;
        _called = true;
        return value;
    }

    function _getTokenBalanceGivenInvariantAndAllOtherBalances(
        uint256 amplificationParameter,
        uint256[] memory balances,
        uint256 invariant,
        uint256 tokenIndex
    ) public returns (uint256) {
        uint256 value;
        _called = true;
        return value;
    }

    function _getRate(
        uint256[] memory balances,
        uint256 amp,
        uint256 supply
    ) public returns (uint256) {
        uint256 value;
        _called = true;
        return value;
    }
}
