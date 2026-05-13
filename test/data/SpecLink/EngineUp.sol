// SPDX-License-Identifier: EPL-2.0

import "./Engine.sol";

contract EngineUp is Engine {

  function divUp(uint256 a, uint256 b) internal pure returns (uint256) {
    return (a + b - 1) / b;
  }
  
  function compute(uint256 v) external pure returns (uint256) {
    return divUp(v, 3);
  }

}