package com.certora.wala.cast.solidity.test.json;

import java.io.File;

import org.json.JSONArray;

import com.jayway.jsonpath.DocumentContext;

public class TestMorphoSharePrice extends AbstractTest {

	protected File confFile() {
		return new File(testDir(), "SharePrice.conf");
	}

	@Override
	protected String testDir() {
		return "test/data/MorphoV2/SharePricel";
	}

	@Override
	void checkResult(DocumentContext jsonParser) {
		
		JSONArray result = jsonParser.read("$.graphs[*].nodes['0'].metadata[?(@.method == '<Code body of function withdraw>' && @.return contains 'Either' && @.roundings['[76,27-76,84]'].rounding == '< solidity, Ltuple, 0, <solidity,Puint256> >=Down')]");		
		System.err.println(result);
		assert !result.isEmpty();
	}

}
