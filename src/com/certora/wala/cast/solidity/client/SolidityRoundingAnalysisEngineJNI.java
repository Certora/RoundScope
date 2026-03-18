package com.certora.wala.cast.solidity.client;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.Collections;

import com.certora.wala.cast.solidity.loader.SolidityJNILoaderFactory;
import com.certora.wala.cast.solidity.loader.SolidityLoader;
import com.certora.wala.cast.solidity.loader.SolidityLoaderFactory;
import com.ibm.wala.cast.ipa.callgraph.CAstAnalysisScope;
import com.ibm.wala.classLoader.Module;
import com.ibm.wala.util.config.StringFilter;

public class SolidityRoundingAnalysisEngineJNI extends SolidityRoundingAnalysisEngine {

	public SolidityRoundingAnalysisEngineJNI(File confFile) throws FileNotFoundException {
		super(confFile);
	}

	@Override
	protected SolidityLoaderFactory makeClassLoaderFactory(StringFilter exclusions) {
		return new SolidityJNILoaderFactory(confFile, conf.getIncludePath());
	}

	@Override
	public void buildAnalysisScope() throws IOException {
		loaders = makeClassLoaderFactory(null); 

		Module[] solidityFiles = conf.getFiles().toArray(new Module[conf.getFiles().size()]);
		
		scope = new CAstAnalysisScope(solidityFiles, loaders,
				Collections.singleton(SolidityLoader.solidity));
	}


}
