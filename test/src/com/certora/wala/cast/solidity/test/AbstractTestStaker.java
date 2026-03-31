package com.certora.wala.cast.solidity.test;

import org.json.JSONArray;

import com.jayway.jsonpath.DocumentContext;

public interface AbstractTestStaker extends CheckResult {
	
	default void checkResult(DocumentContext jsonParser) {
		// at least some mulDivUp should round up. 
		JSONArray result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function mulDivUp>' && @.return == 'Up') ]");		
		assert !result.isEmpty();
		
		// no mulDivUp should round down. 
		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function mulDivUp>' && @.return == 'Down') ]");		
		assert result.isEmpty();

		// at least some mulDivDown should round down. 
		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function mulDivDown>' && @.return == 'Down') ]");		
		assert !result.isEmpty();
		
		// no mulDivDown should round up. 
		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function mulDivDown>' && @.return == 'Up') ]");		
		assert result.isEmpty();
	}
}
