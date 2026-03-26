package com.certora.wala.cast.solidity.test.json;

import java.io.File;

import org.json.JSONArray;

import com.jayway.jsonpath.DocumentContext;

public class TestInfiniFiMintController extends AbstractTest {

	protected File confFile() {
		return new File(testDir(), "MintController.conf");
	}

	@Override
	protected String testDir() {
		return "test/data/InfiniFi/MintController";
	}

	@Override
	void checkResult(DocumentContext jsonParser) {

		JSONArray result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function divWadUp>' && @.return == 'Up' && @.parameters[1].rounding == 'Neither' && @.parameters[2].rounding == 'Neither')]");		
		System.err.println(result);
		assert !result.isEmpty();

		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function divWadUp>' && @.return != 'Up' && @.parameters[1].rounding == 'Neither' && @.parameters[2].rounding == 'Neither')]");		
		System.err.println(result);
		assert result.isEmpty();

		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function divWadDown>' && @.return == 'Down' && @.parameters[1].rounding == 'Neither' && @.parameters[2].rounding == 'Neither')]");		
		System.err.println(result);
		assert !result.isEmpty();

		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function divWadDown>' && @.return != 'Down' && @.parameters[1].rounding == 'Neither' && @.parameters[2].rounding == 'Neither')]");		
		System.err.println(result);
		assert result.isEmpty();

		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function totalAssetsValue>' && @.return == 'Down' )]");		
		System.err.println(result);
		assert !result.isEmpty();

		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function balanceOf>' && @.return == 'Down' && @.methodPosition =~ /.*MockAToken.sol:\\[19,4-21,5\\]$/ )]");		
		System.err.println(result);
		assert !result.isEmpty();

		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function balanceOf>' && @.return == 'Neither' && @.methodPosition =~ /.*ERC20.sol:\\[92,4-94,5\\]$/ )]");		
		System.err.println(result);
		assert !result.isEmpty();
	}

}
