package com.certora.wala.cast.solidity.test.jni;

import com.certora.wala.cast.solidity.test.AbstractTestStaker;

public class TestStaker extends AbstractJNITest implements AbstractTestStaker {

	@Override
	protected String testDir() {
		return "test/data/Staker";
	}

}
