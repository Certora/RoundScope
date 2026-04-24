package com.certora.wala.cast.solidity.loader;

import java.util.Collection;
import java.util.Collections;
import java.util.List;

import com.certora.wala.cast.solidity.tree.SolidityCAstType;
import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.ibm.wala.cast.tree.CAstQualifier;
import com.ibm.wala.cast.tree.CAstType;
import com.ibm.wala.types.TypeReference;

public class EnumType implements CAstType.Class {

	private final String name;
	private final List<String> members;

	public EnumType(String name, List<String> members) {
		this.name = name;
		this.members = members;
		
		SolidityCAstType.record(name, this, TypeReference.findOrCreate(SolidityTypes.solidity, 'L' + name));;
	}

	@Override
	public String getName() {
		return name;
	}

	public List<String> getMembers() {
		return members;
	}

	@Override
	public Collection<CAstType> getSupertypes() {
		return Collections.singleton(SolidityCAstType.get("enum"));
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
