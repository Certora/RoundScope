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
