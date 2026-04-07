package com.certora.wala.cast.solidity.test;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;

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
	
	protected DocumentContext parse(JSONObject o) {
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

}
