package com.certora.wala.cast.solidity.loader;

import java.util.Collection;
import java.util.Collections;
import java.util.Set;

import com.certora.wala.cast.solidity.tree.SolidityCAstType;
import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.ibm.wala.cast.tree.CAstQualifier;
import com.ibm.wala.cast.tree.CAstType;
import com.ibm.wala.cast.tree.CAstType.Class;
import com.ibm.wala.types.TypeReference;

public class InterfaceType implements Class {
	private final String name;
	private final Set<CAstType> superTypes;
	
	public InterfaceType(String name) {
		this(name, Collections.emptySet());
	}

	public InterfaceType(String name, Set<CAstType> superTypes) {
		super();
		this.name = name;
		this.superTypes = superTypes;
		
		SolidityCAstType.record(name, this, TypeReference.findOrCreate(SolidityTypes.solidity, 'L' + name));;
		SolidityCAstType.record("interface "+name, this, TypeReference.findOrCreate(SolidityTypes.solidity, 'L' + name));;
	}

	@Override
	public String getName() {
		return name;
	}

	@Override
	public Set<CAstType> getSupertypes() {
		return superTypes;
	}

	@Override
	public Collection<CAstQualifier> getQualifiers() {
		// TODO Auto-generated method stub
		return null;
	}

	@Override
	public boolean isInterface() {
		return true;
	}

	@Override
	public String toString() {
		if (superTypes.isEmpty()) {
			return "<contract " + name + ">";
		} else {
			return "<contract " + name + superTypes + ">";
		}
	}
}
