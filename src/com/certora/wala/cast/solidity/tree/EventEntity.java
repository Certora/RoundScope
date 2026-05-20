/*
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License v. 2.0 which is available at
 * http://eclipse.org.
 *
 * This Source Code may also be made available under the following Secondary
 * Licenses when the conditions for such availability set forth in the Eclipse
 * Public License, v. 2.0 are satisfied: {name license(s), version(s), and
 * exceptions or additional permissions here}.
 *
 * SPDX-License-Identifier: EPL-2.0
 */
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
