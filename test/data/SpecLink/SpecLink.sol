// SPDX-License-Identifier: EPL-2.0

import "./Engine.sol";

contract SpecLink {

  Engine[] engines;

  function compute0(uint256 v) public returns (uint256) {
    return engines[0].compute(v);
  }

  function compute1(uint256 v) public returns (uint256) {
    return engines[1].compute(v);
  }

  function computeN(uint256 n, uint256 v) public returns (uint256) {
    return engines[n].compute(v);
  }

}