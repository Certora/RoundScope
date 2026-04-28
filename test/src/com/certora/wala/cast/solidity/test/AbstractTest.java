package com.certora.wala.cast.solidity.test;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;

import org.json.JSONArray;
import org.json.JSONObject;
import org.junit.jupiter.api.Test;

import com.ibm.wala.util.CancelException;
import com.jayway.jsonpath.Configuration;
import com.jayway.jsonpath.DocumentContext;
import com.jayway.jsonpath.JsonPath;
import com.jayway.jsonpath.spi.json.JsonOrgJsonProvider;
import com.jayway.jsonpath.spi.mapper.JsonOrgMappingProvider;

public abstract class AbstractTest implements CheckResult {
	abstract protected String testDir();
	
	abstract protected JSONObject runAnalysis() throws IllegalArgumentException, IOException, CancelException;
	
	protected final Configuration configuration = Configuration.builder()
		.jsonProvider(new JsonOrgJsonProvider())
		.mappingProvider(new JsonOrgMappingProvider())
		.build();

	protected File confFile() {
		return new File(testDir(), "run.conf");
	}
	
	protected DocumentContext parse(Object o) {
		return JsonPath.using(configuration).parse(o);
	}
	
	protected void testAnalysis(JSONObject output) {		
		checkResult(parse(output));

	}

	@Test
	public void test() throws IllegalArgumentException, IOException, CancelException {
		JSONObject result = runAnalysis();
		File outFile = File.createTempFile("roundAbout", ".json");
		System.err.println(outFile);
		try (FileWriter w = new FileWriter(outFile)) {
			result.write(w, 3, 0);
		}
		testAnalysis(result);
	}

	protected void checkFloorCeilingFunction(DocumentContext jsonParser, String function) {
		JSONArray mulDiv = jsonParser.read("$.graphs[*].nodes[*].metadata[?(@.method == '<Code body of function " + function + ">' && @.return != 'Neither')]");
		System.err.println(mulDiv);
		assert !mulDiv.isEmpty();
		
		int upCount = 0, downCount = 0;
		for(Object o : mulDiv) {
			DocumentContext methods = parse(o);	
			JSONArray specifiedUp = methods.read("$.parameters[?(@.value == 'Ceil')]");
			if (! specifiedUp.isEmpty()) {
				String s = ((JSONObject)o).getString("return");
				assert "Up".equals(s) || "Inconsistent".equals(s) : s;
				upCount++;
			}
			JSONArray specifiedDown = methods.read("$.parameters[?(@.value == 'Floor')]");
			if (! specifiedDown.isEmpty()) {
				String s = ((JSONObject)o).getString("return");
				assert "Down".equals(s) || "Inconsistent".equals(s) : s;
				downCount++;
			}
		}
		System.err.println(upCount + " " + downCount);
		assert upCount > 0 && downCount > 0;
	}

}
