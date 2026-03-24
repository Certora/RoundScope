package com.certora.wala.cast.solidity.test.json;

import org.json.JSONArray;

import com.jayway.jsonpath.DocumentContext;

public abstract class AbstractTestStaker extends AbstractTest {
	
	protected void checkResult(DocumentContext jsonParser) {
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
