package com.certora.wala.cast.solidity.test.jni;

import java.io.IOException;

import org.json.JSONObject;

import com.certora.wala.cast.solidity.client.SolidityRoundingAnalysisEngineJNI;
import com.certora.wala.cast.solidity.test.AbstractTest;
import com.ibm.wala.util.CancelException;

public abstract class AbstractJNITest extends AbstractTest {

	@Override
	protected JSONObject runAnalysis() throws IllegalArgumentException, IOException, CancelException {
		SolidityRoundingAnalysisEngineJNI E = new SolidityRoundingAnalysisEngineJNI(confFile());
		return E.analyze();
	}

}
