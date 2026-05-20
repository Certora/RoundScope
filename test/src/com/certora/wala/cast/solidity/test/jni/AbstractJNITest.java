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
package com.certora.wala.cast.solidity.test.jni;

import java.io.IOException;

import org.json.JSONObject;
import org.junit.jupiter.api.Tag;

import com.certora.wala.cast.solidity.client.SolidityRoundingAnalysisEngineJNI;
import com.certora.wala.cast.solidity.test.AbstractTest;
import com.ibm.wala.util.CancelException;

@Tag("jni")
public abstract class AbstractJNITest extends AbstractTest {

	@Override
	protected JSONObject runAnalysis() throws IllegalArgumentException, IOException, CancelException {
		SolidityRoundingAnalysisEngineJNI E = new SolidityRoundingAnalysisEngineJNI(confFile());
		return E.analyze();
	}

}
