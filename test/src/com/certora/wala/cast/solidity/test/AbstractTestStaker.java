/*
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License v. 2.0 which is available at
 * http://eclipse.org.
 *
 * This Source Code may also be made available under the following Secondary
 * Licenses when the conditions for such availability set forth in the Eclipse
 * Public License, v. 2.0 are satisfied: {name license(s), version(s), and
 * exceptions or additional permissions here}.
 *
 * SPDX-License-Identifier: EPL-2.0
 */
package com.certora.wala.cast.solidity.test;

import org.json.JSONArray;

import com.jayway.jsonpath.DocumentContext;

public interface AbstractTestStaker extends CheckResult {
	
	default void checkResult(DocumentContext jsonParser) {
		// withdrawB rounds up. 
		JSONArray result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function withdrawB>' && @.return == 'Up') ]");		
		assert !result.isEmpty();
		System.err.println(result);
		
		// unstakeB rounds up. 
		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function unstakeB>' && @.return == 'Up') ]");		
		assert !result.isEmpty();
		System.err.println(result);

		// stakeB rounds up. 
		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function stakeB>' && @.return == 'Up') ]");		
		assert !result.isEmpty();
		System.err.println(result);

		// withdrawA rounds dowm. 
		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function withdrawA>' && @.return == 'Down') ]");		
		assert !result.isEmpty();
		System.err.println(result);

		// unstakeA rounds down. 
		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function unstakeA>' && @.return == 'Down') ]");		
		assert !result.isEmpty();
		System.err.println(result);

		// stakeA rounds down. 
		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function stakeA>' && @.return == 'Down') ]");		
		assert !result.isEmpty();
		System.err.println(result);

	}
}
