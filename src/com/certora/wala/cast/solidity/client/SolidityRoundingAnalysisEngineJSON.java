package com.certora.wala.cast.solidity.client;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.Arrays;
import java.util.Collections;

import com.certora.wala.cast.solidity.loader.SolidityJSONLoaderFactory;
import com.certora.wala.cast.solidity.loader.SolidityLoader;
import com.certora.wala.cast.solidity.loader.SolidityLoaderFactory;
import com.ibm.wala.cast.ipa.callgraph.CAstAnalysisScope;
import com.ibm.wala.classLoader.Module;
import com.ibm.wala.classLoader.SourceFileModule;
import com.ibm.wala.util.config.StringFilter;

public class SolidityRoundingAnalysisEngineJSON extends SolidityRoundingAnalysisEngine {
	private final String[] jsonFileNames;
	
	public SolidityRoundingAnalysisEngineJSON(File confFile, String[] jsonFileNames) throws FileNotFoundException {
		super(confFile);
		this.jsonFileNames = jsonFileNames;
	}

	@Override
	protected SolidityLoaderFactory makeClassLoaderFactory(StringFilter exclusions) {
		return new SolidityJSONLoaderFactory();
	}

	@Override
	public void buildAnalysisScope() throws IOException {
		loaders = makeClassLoaderFactory(null); 

		Module[] solidityFiles = Arrays.stream(jsonFileNames).map(f -> new SourceFileModule(new File(f), f, null)).toArray(i -> new Module[i]);
		
		scope = new CAstAnalysisScope(solidityFiles, loaders,
				Collections.singleton(SolidityLoader.solidity));
	}

	
}
