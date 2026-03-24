package com.certora.wala.cast.solidity.test.json;

import java.io.File;

import org.json.JSONArray;

import com.jayway.jsonpath.DocumentContext;

public class TestAaveV4Liquidation extends AbstractTest {

	protected File confFile() {
		return new File(testDir(), "Liquidation.conf");
	}

	@Override
	protected String testDir() {
		return "test/data/AaveV4/Liquidation";
	}

	@Override
	void checkResult(DocumentContext jsonParser) {
	
		JSONArray result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function percentMulUp>' && @.return == 'Up')]");		
		System.err.println(result);
		assert !result.isEmpty();

	}

}
