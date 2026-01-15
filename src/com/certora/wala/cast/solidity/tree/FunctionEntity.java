package com.certora.wala.cast.solidity.tree;

import java.util.Collection;
import java.util.Collections;

import com.ibm.wala.cast.tree.CAstNode;
import com.ibm.wala.cast.tree.CAstQualifier;
import com.ibm.wala.cast.tree.CAstSourcePositionMap.Position;
import com.ibm.wala.cast.tree.CAstType;

public class FunctionEntity extends CallableEntity {

	private Collection<CAstQualifier> qualifiers;

	public FunctionEntity(String name,
			CAstType.Function type, 
			String[] argumentNames, 
			Position location,
			Position nameLocation,
			Position[] argLocations,
			Collection<CAstQualifier> qualifiers,
			CAstNode ast) {
		super(name, type, argumentNames, location, nameLocation, argLocations);
		this.Ast = ast;
		this.qualifiers = qualifiers;
	}

	public FunctionEntity(String name,
			CAstType.Function type, 
			String[] argumentNames, 
			Position location,
			Position nameLocation,
			Position[] argLocations,
			CAstQualifier qualifier,
			CAstNode ast) {
		this(name, type, argumentNames, location, nameLocation, argLocations, Collections.singleton(qualifier), ast);
	}

	@Override
	public Collection<CAstQualifier> getQualifiers() {
		return qualifiers;
	}

}
