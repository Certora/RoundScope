package com.certora.wala.cast.solidity.loader;

import java.util.Collection;
import java.util.Collections;
import java.util.Set;
import java.util.stream.Collectors;

import com.certora.wala.cast.solidity.tree.SolidityCAstType;
import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.ibm.wala.cast.tree.CAstQualifier;
import com.ibm.wala.cast.tree.CAstType;
import com.ibm.wala.cast.tree.CAstType.Class;
import com.ibm.wala.types.TypeReference;

public class ContractType implements Class {
	private final String name;
	private final Set<String> superTypes;
	private final Set<CAstQualifier> qualifiers;
	
	public ContractType(String name) {
		this(name, Collections.emptySet(), Collections.emptySet());
	}

	public ContractType(String name, Set<String> superTypes, Set<CAstQualifier> qualifiers) {
		super();
		this.name = name;
		this.superTypes = superTypes;
		this.qualifiers = qualifiers;
		
		SolidityCAstType.record(name, this, TypeReference.findOrCreate(SolidityTypes.solidity, 'L' + name));;
		
		assert name.startsWith("contract ") : name;
		SolidityCAstType.record(name.substring(9), this, TypeReference.findOrCreate(SolidityTypes.solidity, 'L' + name));;
	}

	@Override
	public String getName() {
		return name;
	}

	@Override
	public Set<CAstType> getSupertypes() {
		return superTypes.stream().map(s -> SolidityCAstType.get(s)).collect(Collectors.toSet());
	}

	@Override
	public Collection<CAstQualifier> getQualifiers() {
		return qualifiers;
	}

	@Override
	public boolean isInterface() {
		return false;
	}

	@Override
	public String toString() {
		if (superTypes.isEmpty()) {
			return "<" + name + ">";
		} else {
			return "<" + name + superTypes + ">";
		}
	}
}
