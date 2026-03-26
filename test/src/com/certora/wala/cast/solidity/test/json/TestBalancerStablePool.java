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
		JSONArray result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function _calcOutGivenIn>' && @.return == 'Either')]"); 
		System.err.println(result);
		assert !result.isEmpty();

		result = jsonParser.read("$.graphs[?(@.nodes['0'].metadata.method == '<Code body of function onSwap>' && $.nodes[*].metadata[?(@.method == '<Code body of function _swapGivenOut>' && @.return == 'Either' && @.roundings['[76,27-76,84]'].rounding == 'Either' && @.roundings['[74,29-74,83]'].rounding == 'Down' && @.roundings['[79,19-79,66]'].rounding == 'Either')] )]");		 
		System.err.println(result.length());
		assert !result.isEmpty();

		/*
		boolean any = false;
		for(int i = 0; i < result.length(); i++) {
			DocumentContext onSwap = parse(result.getJSONObject(i));
			result = onSwap.read("$.nodes[*].metadata[?(@.method == '<Code body of function _swapGivenOut>' && @.return == 'Either' && @.roundings['[76,27-76,84]'].rounding == 'Either' && @.roundings['[74,29-74,83]'].rounding == 'Down' && @.roundings['[79,19-79,66]'].rounding == 'Either')]");		
			System.err.println(result);
			any |= !result.isEmpty();
		}
		assert any;
		*/
		
		result = jsonParser.read("$.graphs[?(@.nodes['0'].metadata.method == '<Code body of function onJoinPool>')]"); 
		assert !result.isEmpty();

		boolean any = false;
		for(int i = 0; i < result.length(); i++) {
			DocumentContext onJoinPool = parse(result.getJSONObject(i));
			result = onJoinPool.read("$.nodes[*].metadata[?(@.method == '<Code body of function _onJoinPool>')]"); 
			System.err.println(result);
			any |= !result.isEmpty();
		}
		assert any;
	}
}
