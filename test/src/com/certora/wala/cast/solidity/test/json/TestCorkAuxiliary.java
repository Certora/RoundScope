package com.certora.wala.cast.solidity.test.json;

import java.io.File;

import org.json.JSONArray;

import com.jayway.jsonpath.DocumentContext;

public class TestCorkAuxiliary extends AbstractTest {

	protected File confFile() {
		return new File(testDir(), "0-auxiliary.conf");
	}

	@Override
	protected String testDir() {
		return "test/data/Cork/0Auxiliary";
	}

	@Override
	void checkResult(DocumentContext jsonParser) {

		JSONArray result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function ceilDiv>' && @.return == 'Up' && @.parameters[1].rounding == 'Neither' && @.parameters[2].rounding == 'Neither')]");		
		System.err.println(result);
		assert !result.isEmpty();

	}

}
