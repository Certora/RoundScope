package com.certora.wala.cast.solidity.test.json;

import com.certora.wala.cast.solidity.test.AbstractTestForcedRounding;

public class TestForcedRounding extends AbstractJsonTest implements AbstractTestForcedRounding {

	@Override
	protected String testDir() {
		return "test/data/ForcedRounding";
	}

}
