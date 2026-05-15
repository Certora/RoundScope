
using SpecLink as specLink;
using EngineUp as engineUp;
using EngineDown as engineDown;

links {
    specLink.engines[0] => engineUp;
    specLink.engines[1] => engineDown;
}

methods {
    function compute0(uint256) external returns (uint256) envfree;
    function compute1(uint256) external returns (uint256) envfree;
    function computeN(uint256, uint256) external returns (uint256) envfree;
}

rule ruleUp {
  assert compute0(3) == 2;
  assert computeN(3, 0) == 2;
}

rule ruleDown {
  assert compute1(3) == 1;
  assert computeN(3, 1) == 1;
}
