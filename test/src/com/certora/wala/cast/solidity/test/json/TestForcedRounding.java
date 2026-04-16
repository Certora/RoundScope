package com.certora.wala.cast.solidity.test.json;

import org.json.JSONArray;

import com.certora.wala.cast.solidity.test.AbstractTestForcedRounding;
import com.jayway.jsonpath.DocumentContext;

public class TestForcedRounding extends AbstractJsonTest implements AbstractTestForcedRounding {

	@Override
	protected String testDir() {
		return "test/data/ForcedRounding";
	}

	@Override
	public void checkResult(DocumentContext jsonParser) {
		JSONArray result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function forcedDown>' && @.return == 'Down') ]");		
		System.err.println(result);
		assert !result.isEmpty();

		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function forcedDown>' && @.return != 'Down') ]");		
		System.err.println(result);
		assert result.isEmpty();

		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function forcedUp>' && @.return == 'Up') ]");		
		System.err.println(result);
		assert !result.isEmpty();

		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function forcedUp>' && @.return != 'Up') ]");		
		System.err.println(result);
		assert result.isEmpty();
	}

	
}
