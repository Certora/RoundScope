package com.certora.wala.cast.solidity.tree;

import java.util.Collection;
import java.util.Collections;

import com.ibm.wala.cast.tree.CAstNode;
import com.ibm.wala.cast.tree.CAstQualifier;
import com.ibm.wala.cast.tree.CAstSourcePositionMap.Position;
import com.ibm.wala.cast.tree.CAstType.Function;

public class EventEntity extends CallableEntity {

	public EventEntity(String name, Function type, String[] argumentNames, Position location, Position nameLocation,
			Position[] argLocations, Collection<CAstQualifier> qualifiers, CAstNode ast) {
		super(name, type, argumentNames, location, nameLocation, argLocations);
	}

	@Override
	public Collection<CAstQualifier> getQualifiers() {
		return Collections.singleton(CAstQualifier.ABSTRACT);
	}

}
