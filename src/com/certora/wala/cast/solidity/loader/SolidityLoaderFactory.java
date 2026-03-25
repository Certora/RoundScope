package com.certora.wala.cast.solidity.loader;

import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.ibm.wala.cast.loader.SingleClassLoaderFactory;
import com.ibm.wala.types.ClassLoaderReference;

public abstract class SolidityLoaderFactory extends SingleClassLoaderFactory {

	@Override
	public ClassLoaderReference getTheReference() {
		return SolidityTypes.solidity;
	}

}
