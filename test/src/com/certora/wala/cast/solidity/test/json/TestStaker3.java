/*
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License v. 2.0 which is available at
 * http://eclipse.org.
 *
 * This Source Code may also be made available under the following Secondary
 * Licenses when the conditions for such availability set forth in the Eclipse
 * Public License, v. 2.0 are satisfied: {name license(s), version(s), and
 * exceptions or additional permissions here}.
 *
 * SPDX-License-Identifier: EPL-2.0
 */
package com.certora.wala.cast.solidity.test.json;

import com.certora.wala.cast.solidity.test.AbstractTestStaker;

public class TestStaker3 extends AbstractJsonTest implements AbstractTestStaker {

	@Override
	protected String testDir() {
		return "test/data/Staker3";
	}


}
