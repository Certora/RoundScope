package com.certora.wala.cast.solidity.tree;

import java.util.Collection;
import java.util.Collections;

import com.certora.wala.cast.solidity.loader.FunctionType;
import com.ibm.wala.cast.tree.CAstType;

public class SolidityFunctionType implements CAstType {
	private final String name;
	private final CAstType[] parameters;
	private final CAstType[] returns;
	private final boolean event;

	public SolidityFunctionType(String name, CAstType[] parameters, CAstType[] returns, boolean event) {
		this.name = name;
		this.parameters = parameters;
		this.returns = returns;
		this.event = event;
	}

	@Override
	public String getName() {
		return name;
	}

	public CAstType[] parameters() {
		return parameters;
	}

	public CAstType[] returns() {
		return returns;
	}
	
	public boolean isEvent() {
		return event;
	}
	
	@Override
	public Collection<CAstType> getSupertypes() {
		return Collections.emptySet();
	}

	
	@Override
	public String toString() {
		return FunctionType.signature(name, parameters, returns!=null? returns[0]: null);
	}
}
