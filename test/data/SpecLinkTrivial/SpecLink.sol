// SPDX-License-Identifier: EPL-2.0

import "./Engine.sol";

contract SpecLink {

  Engine[] engines;

  function compute0(uint256 v) public returns (uint256) {
    return engines[0].compute(v);
  }

}