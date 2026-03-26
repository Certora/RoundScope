package com.certora.wala.cast.solidity.test.json;

import java.io.File;
import java.io.IOException;

import org.json.JSONObject;
import org.junit.jupiter.api.Test;

import com.certora.wala.cast.solidity.client.SolidityRoundingAnalysisEngineJSON;
import com.ibm.wala.util.CancelException;
import com.jayway.jsonpath.Configuration;
import com.jayway.jsonpath.DocumentContext;
import com.jayway.jsonpath.JsonPath;
import com.jayway.jsonpath.spi.json.JsonOrgJsonProvider;
import com.jayway.jsonpath.spi.mapper.JsonOrgMappingProvider;

public abstract class AbstractTest {

	abstract protected String testDir();
	
	abstract void checkResult(DocumentContext jsonParser);

	protected final Configuration configuration = Configuration.builder()
		.jsonProvider(new JsonOrgJsonProvider())
		.mappingProvider(new JsonOrgMappingProvider())
		.build();

	protected File confFile() {
		return new File(testDir(), "run.conf");
	}
	
	private final File astsFile;
	
	
	{
		File bz2 = new File(testDir(),  ".certora_internal/latest/.asts.json.bz2");
		astsFile = bz2.exists()? bz2: new File(testDir(), ".certora_internal/latest/.asts.json");
	}

	protected JSONObject runAnalysis() throws IllegalArgumentException, IOException, CancelException {
		SolidityRoundingAnalysisEngineJSON E = new SolidityRoundingAnalysisEngineJSON(confFile(), astsFile.getAbsolutePath());
		return E.analyze();
	}

	protected DocumentContext parse(JSONObject o) {
		return JsonPath.using(configuration).parse(o);
	}
	
	protected void testAnalysis(JSONObject output) {		
		checkResult(parse(output));

	}

	@Test
	public void test() throws IllegalArgumentException, IOException, CancelException {
		testAnalysis(runAnalysis());
	}

}
