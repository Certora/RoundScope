package com.certora.wala.cast.solidity.loader;

import java.util.Collection;
import java.util.Collections;

import com.certora.wala.cast.solidity.tree.SolidityCAstType;
import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.ibm.wala.cast.tree.CAstQualifier;
import com.ibm.wala.cast.tree.CAstType;
import com.ibm.wala.cast.tree.CAstType.Class;
import com.ibm.wala.types.TypeReference;

public class StructType implements Class {

	private String name;

	public StructType(String name) {
		this.name = name;

		SolidityCAstType.record(name, this, TypeReference.findOrCreate(SolidityTypes.solidity, 'L' + name));;
		SolidityCAstType.record("struct "+name, this, TypeReference.findOrCreate(SolidityTypes.solidity, 'L' + name));;
	}

	@Override
	public String getName() {
		return name;
	}

	@Override
	public Collection<CAstType> getSupertypes() {
		return Collections.singleton(SolidityCAstType.get("struct"));
	}

	@Override
	public boolean isInterface() {
		return false;
	}

	@Override
	public Collection<CAstQualifier> getQualifiers() {
		return Collections.emptySet();
	}

}
