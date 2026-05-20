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
package com.certora.wala.cast.solidity.client;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.Collections;

import com.certora.wala.cast.solidity.loader.SolidityJNILoaderFactory;
import com.certora.wala.cast.solidity.loader.SolidityLoader;
import com.certora.wala.cast.solidity.loader.SolidityLoaderFactory;
import com.certora.wala.cast.solidity.util.SpecFileJSON;
import com.ibm.wala.cast.ipa.callgraph.CAstAnalysisScope;
import com.ibm.wala.classLoader.Module;
import com.ibm.wala.util.config.StringFilter;

public class SolidityRoundingAnalysisEngineJNI extends SolidityRoundingAnalysisEngine {

	public SolidityRoundingAnalysisEngineJNI(File confFile) throws FileNotFoundException {
		super(confFile);
	}

	public SolidityRoundingAnalysisEngineJNI(File confFile, SpecFileJSON spec) throws FileNotFoundException {
		super(confFile, spec);
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
