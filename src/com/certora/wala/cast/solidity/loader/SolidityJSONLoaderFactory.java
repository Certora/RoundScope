package com.certora.wala.cast.solidity.loader;

import com.ibm.wala.classLoader.IClassLoader;
import com.ibm.wala.ipa.cha.IClassHierarchy;

public class SolidityJSONLoaderFactory extends SolidityLoaderFactory {

	@Override
	protected IClassLoader makeTheLoader(IClassHierarchy cha) {
		return new SolidityJSONLoader(cha, null);
	}
}
