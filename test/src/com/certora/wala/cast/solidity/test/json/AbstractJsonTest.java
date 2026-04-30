package com.certora.wala.cast.solidity.test.json;

import java.io.File;
import java.io.IOException;

import org.json.JSONObject;

import com.certora.wala.cast.solidity.client.SolidityRoundingAnalysisEngineJSON;
import com.certora.wala.cast.solidity.test.AbstractTest;
import com.ibm.wala.util.CancelException;

public abstract class AbstractJsonTest extends AbstractTest {

	private final File astsFile;
	
	{
		File astDir = astDir();
		File bz2 = new File(astDir, ".asts.json.bz2");
		astsFile = bz2.exists()? bz2: new File(astDir, ".asts.json");
	}
	
	protected File astDir() {
		return new File(testDir(), "ast");
	}

	protected JSONObject runAnalysis() throws IllegalArgumentException, IOException, CancelException {
		SolidityRoundingAnalysisEngineJSON E = new SolidityRoundingAnalysisEngineJSON(confFile(), astsFile.getAbsolutePath());
		try {
			return E.analyze();
		} finally {
			synchronized (System.err) {
				System.err.println("timing: stats for " + getClass().getSimpleName());
				System.err.println("timing: " + E.statistics);
				E.statistics.forEach((x, y) -> { 
					if (x.contains("code_size")) {
						E.statistics.forEach((a, b) -> { 
							if (!a.contains("code_size")) {	
								System.err.println("timing: " + a + "/" + x + " = " + (b.doubleValue()/1_000_000_000) / y.doubleValue());
							}
						});
					}
				});
			}
		}
	}

}
