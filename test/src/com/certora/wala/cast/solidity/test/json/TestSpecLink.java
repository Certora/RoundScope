package com.certora.wala.cast.solidity.test.json;

import java.io.File;

import org.json.JSONArray;

import com.jayway.jsonpath.DocumentContext;

public class TestSpecLink extends AbstractJsonTest {

	@Override
	public void checkResult(DocumentContext jsonParser) {
		JSONArray result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function computeN>' && @.return == 'Either') ]");		
		assert !result.isEmpty();
		System.err.println(result);
	}

	@Override
	protected String testDir() {
		return "test/data/SpecLink";
	}

	@Override
	protected File confFile() {
		return new File(testDir(), "SpecLink.conf");
	}

	@Override
	protected File specFile() {
		return new File(testDir(), "SpecLink.json");
	}

}
