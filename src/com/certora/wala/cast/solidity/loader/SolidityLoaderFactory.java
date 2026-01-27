package com.certora.wala.cast.solidity.loader;

import java.io.File;
import java.util.Map;

import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.ibm.wala.cast.loader.SingleClassLoaderFactory;
import com.ibm.wala.classLoader.IClassLoader;
import com.ibm.wala.ipa.cha.IClassHierarchy;
import com.ibm.wala.types.ClassLoaderReference;

public class SolidityLoaderFactory extends SingleClassLoaderFactory {

	private final Map<String, File> includePath;
	private File confFile;

	public SolidityLoaderFactory(File confFile, Map<String, File> includePath) {
		this.confFile = confFile;
		this.includePath = includePath;
	}

	@Override
	public ClassLoaderReference getTheReference() {
		return SolidityTypes.solidity;
	}

	@Override
	protected IClassLoader makeTheLoader(IClassHierarchy cha) {
		return new SolidityLoader(confFile, includePath, cha, null);
	}

}
