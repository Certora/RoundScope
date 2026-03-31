package com.certora.wala.cast.solidity.loader;

import org.json.JSONObject;

import com.ibm.wala.classLoader.IClassLoader;
import com.ibm.wala.ipa.cha.IClassHierarchy;

public class SolidityJSONLoaderFactory extends SolidityLoaderFactory {
	private final JSONObject originalTree;
	
	public SolidityJSONLoaderFactory(JSONObject originalTree) {
		this.originalTree = originalTree;
	}

	@Override
	protected IClassLoader makeTheLoader(IClassHierarchy cha) {
		return new SolidityJSONLoader(cha, null, originalTree);
	}
}
