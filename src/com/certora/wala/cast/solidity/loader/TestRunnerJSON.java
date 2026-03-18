package com.certora.wala.cast.solidity.loader;

import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import org.json.JSONObject;

import com.certora.wala.cast.solidity.client.SolidityRoundingAnalysisEngine;
import com.certora.wala.cast.solidity.client.SolidityRoundingAnalysisEngineJSON;
import com.github.erosb.jsonsKema.JsonParser;
import com.github.erosb.jsonsKema.Schema;
import com.github.erosb.jsonsKema.SchemaLoader;
import com.github.erosb.jsonsKema.ValidationFailure;
import com.github.erosb.jsonsKema.Validator;
import com.ibm.wala.util.CancelException;

public class TestRunnerJSON {

	public static void main(String... args) throws IllegalArgumentException, IOException, CancelException {
		String conf = args[0];
				
		SolidityRoundingAnalysisEngine E;
		if ("--combined".equalsIgnoreCase(args[2])) {
			E = new SolidityRoundingAnalysisEngineJSON(new File(conf), args[3]);
			
		} else {
			List<String> jsonFiles = new ArrayList<>(Arrays.asList(args));
			jsonFiles.removeFirst();
			jsonFiles.removeFirst();
			E = new SolidityRoundingAnalysisEngineJSON(new File(conf), jsonFiles.toArray(i -> new String[i]));
		}
		
		JSONObject graphs = E.analyze();
					
		try (FileWriter jo = new FileWriter(args[1])) {
			graphs.write(jo, 4, 0);
		}

		Schema schema = SchemaLoader.forURL("https://raw.githubusercontent.com/jsongraph/json-graph-specification/refs/heads/master/json-graph-schema_v2.json").load();
		Validator validator = Validator.forSchema(schema);
		ValidationFailure failure = validator.validate(new JsonParser(new FileReader(args[1])).parse());
		if (failure != null) {
			System.err.println(failure);
		}
	}
}
