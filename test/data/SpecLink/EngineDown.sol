// SPDX-License-Identifier: EPL-2.0

import "./Engine.sol";

contract EngineDown is Engine {

  function divDown(uint256 a, uint256 b) internal pure returns (uint256) {
    return a / b;
  }
  
  function compute(uint256 v) external pure returns (uint256) {
    return divDown(v, 3);
  }

}