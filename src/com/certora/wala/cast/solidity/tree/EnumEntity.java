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

import com.certora.wala.cast.solidity.loader.EnumType;
import com.ibm.wala.cast.ir.translator.AbstractClassEntity;
import com.ibm.wala.cast.tree.CAstSourcePositionMap.Position;

public class EnumEntity extends AbstractClassEntity {
	private final Position sourcePosition;
	private final Position namePosition;

	public EnumEntity(EnumType type, Position sourcePosition, Position namePosition) {
		super(type);
		this.sourcePosition = sourcePosition;
		this.namePosition = namePosition;
	}

	@Override
	public Position getNamePosition() {
		return namePosition;
	}

	@Override
	public Position getPosition(int arg) {
		return null;
	}

}
