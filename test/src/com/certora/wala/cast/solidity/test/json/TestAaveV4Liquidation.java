package com.certora.wala.cast.solidity.test.json;

import java.io.File;

import org.json.JSONArray;

import com.jayway.jsonpath.DocumentContext;

public class TestAaveV4Liquidation extends AbstractJsonTest {

	protected File confFile() {
		return new File(testDir(), "Liquidation.conf");
	}

	@Override
	protected String testDir() {
		return "test/data/AaveV4/Liquidation";
	}

	@Override
	public void checkResult(DocumentContext jsonParser) {
	
		JSONArray result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function percentMulUp>' && @.return == 'Up')]");		
		System.err.println(result);
		assert !result.isEmpty();

		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function percentMulDown>' && @.return == 'Down')]");		
		System.err.println(result);
		assert !result.isEmpty();

		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function rayMulUp>' && @.return == 'Up')]");		
		System.err.println(result);
		assert !result.isEmpty();


	}

}
