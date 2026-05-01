
using SpecLink as specLink;
using EngineUp as engineUp;

links {
    specLink.engines[0] => engineUp;
}

methods {
    function compute0(uint256) external returns (uint256) envfree;
}

rule ruleUp {
  assert compute0(3) == 2;
}

