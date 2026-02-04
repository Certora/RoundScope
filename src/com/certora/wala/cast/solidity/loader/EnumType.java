package com.certora.wala.cast.solidity.loader;

import java.util.Collection;
import java.util.Collections;

import com.certora.wala.cast.solidity.tree.SolidityCAstType;
import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.ibm.wala.cast.tree.CAstType;
import com.ibm.wala.cast.tree.CAstType.Primitive;
import com.ibm.wala.types.TypeReference;

public class EnumType implements Primitive {

	private final String name;
	private final Collection<String> members;

	public EnumType(String name, Collection<String> members) {
		this.name = name;
		this.members = members;
		
		SolidityCAstType.record(name, this, TypeReference.findOrCreate(SolidityTypes.solidity, 'P' + name));;
	}

	@Override
	public String getName() {
		return name;
	}

	public Collection<String> getMembers() {
		return members;
	}

	@Override
	public Collection<CAstType> getSupertypes() {
		return Collections.singleton(SolidityCAstType.get("enum"));
	}

}
