package com.certora.wala.cast.solidity.loader;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import org.json.JSONObject;

import com.certora.wala.cast.solidity.client.SolidityRoundingAnalysisEngine;
import com.certora.wala.cast.solidity.client.SolidityRoundingAnalysisEngineJSON;
import com.ibm.wala.util.CancelException;

public class AnalysisRunnerJSON extends AnalysisRunner {

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
					
		String outFile = args[1];
		try (FileWriter jo = new FileWriter(outFile)) {
			graphs.write(jo, 4, 0);
		}

		validateJSON(outFile);
	}
}
