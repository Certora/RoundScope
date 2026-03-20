package com.certora.wala.cast.solidity.test.json;

import java.io.File;
import java.io.IOException;

import org.json.JSONArray;
import org.json.JSONObject;
import org.junit.jupiter.api.Test;

import com.certora.wala.cast.solidity.client.SolidityRoundingAnalysisEngineJSON;
import com.ibm.wala.util.CancelException;
import com.jayway.jsonpath.Configuration;
import com.jayway.jsonpath.DocumentContext;
import com.jayway.jsonpath.JsonPath;
import com.jayway.jsonpath.spi.json.JsonOrgJsonProvider;
import com.jayway.jsonpath.spi.mapper.JsonOrgMappingProvider;

public abstract class AbstractTestStaker {

	abstract protected String testDir();
	
	private final File confFile = new File(testDir(), "run.conf");
	private final File astsFile = new File(testDir(), ".certora_internal/latest/.asts.json");

	private JSONObject runAnalysis() throws IllegalArgumentException, IOException, CancelException {
		SolidityRoundingAnalysisEngineJSON E = new SolidityRoundingAnalysisEngineJSON(confFile, astsFile.getAbsolutePath());
		return E.analyze();
	}
	
	private void testAnalysis(JSONObject output) {
		Configuration configuration = Configuration.builder()
			    .jsonProvider(new JsonOrgJsonProvider())
			    .mappingProvider(new JsonOrgMappingProvider())
			    .build();
		
		DocumentContext jsonParser = JsonPath.using(configuration).parse(output);
        
		JSONArray result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function mulDivUp>' && @.return == 'Up') ]");		
		assert !result.isEmpty();
		
		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function mulDivUp>' && @.return == 'Down') ]");		
		assert result.isEmpty();

		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function mulDivDown>' && @.return == 'Down') ]");		
		assert !result.isEmpty();
		
		result = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function mulDivDown>' && @.return == 'Up') ]");		
		assert result.isEmpty();

	}
	
	@Test
	public void test() throws IllegalArgumentException, IOException, CancelException {
		testAnalysis(runAnalysis());
	}
}
