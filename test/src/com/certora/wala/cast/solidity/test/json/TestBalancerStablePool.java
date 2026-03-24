package com.certora.wala.cast.solidity.test.json;

import java.io.File;

import org.json.JSONArray;

import com.jayway.jsonpath.DocumentContext;

public class TestBalancerStablePool extends AbstractTest {

	protected File confFile() {
		return new File(testDir(), "stablePool.conf");
	}

	@Override
	protected String testDir() {
		return "test/data/BalancerV2/stablePool";
	}

	@Override
	void checkResult(DocumentContext jsonParser) {
		
		JSONArray result = jsonParser.read("$.graphs[*].nodes['0'].metadata[?(@.method == '<Code body of function _swapGivenOut>' && @.return == 'Either' && @.roundings['[76,27-76,84]'].rounding == 'Either')]");		
		System.err.println(result);
		assert !result.isEmpty();
	}

}
