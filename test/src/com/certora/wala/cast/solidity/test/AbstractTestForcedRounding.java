package com.certora.wala.cast.solidity.test;

import org.json.JSONArray;

import com.jayway.jsonpath.DocumentContext;

public interface AbstractTestForcedRounding extends CheckResult {

	default void checkResult(DocumentContext jsonParser) {
		// forcedDown should round Down
		JSONArray result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function forcedDown>' && @.return == 'Down')]");
		assert !result.isEmpty();

		// forcedDown should NOT round Up
		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function forcedDown>' && @.return == 'Up')]");
		assert result.isEmpty();

		// forcedUp should round Up
		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function forcedUp>' && @.return == 'Up')]");
		assert !result.isEmpty();

		// forcedUp should NOT round Down
		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function forcedUp>' && @.return == 'Down')]");
		assert result.isEmpty();
	}
}
