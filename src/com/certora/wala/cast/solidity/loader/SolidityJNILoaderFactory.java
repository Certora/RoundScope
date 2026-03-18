package com.certora.wala.cast.solidity.loader;

import java.io.File;
import java.util.Map;

import com.ibm.wala.classLoader.IClassLoader;
import com.ibm.wala.ipa.cha.IClassHierarchy;

public class SolidityJNILoaderFactory extends SolidityLoaderFactory {
	protected final Map<String, File> includePath;
	protected File confFile;

	public SolidityJNILoaderFactory(File confFile, Map<String, File> includePath) {
		this.confFile = confFile;
		this.includePath = includePath;
	}

	@Override
	protected IClassLoader makeTheLoader(IClassHierarchy cha) {
		return new SolidityJNILoader(confFile, includePath, cha, null);
	}
}
