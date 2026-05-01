package com.certora.wala.cast.solidity.test.json;

import java.io.File;

import org.json.JSONArray;

import com.jayway.jsonpath.DocumentContext;

public class TestSpecLinkTrivial extends AbstractJsonTest {

	@Override
	public void checkResult(DocumentContext jsonParser) {
		JSONArray result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function compute0>' && @.return == 'Up') ]");		
		assert !result.isEmpty();
		System.err.println(result);
	}

	@Override
	protected String testDir() {
		return "test/data/SpecLinkTrivial";
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
