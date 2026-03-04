package com.certora.wala.cast.solidity.tree;

import java.util.Collection;
import java.util.Collections;
import java.util.Iterator;
import java.util.Map;
import java.util.Set;

import com.ibm.wala.cast.ir.translator.AbstractClassEntity;
import com.ibm.wala.cast.tree.CAstAnnotation;
import com.ibm.wala.cast.tree.CAstEntity;
import com.ibm.wala.cast.tree.CAstNode;
import com.ibm.wala.cast.tree.CAstQualifier;
import com.ibm.wala.cast.tree.CAstSourcePositionMap.Position;
import com.ibm.wala.cast.tree.CAstType;
import com.ibm.wala.util.collections.EmptyIterator;

public class ContractEntity extends AbstractClassEntity {
	private final Position sourcePosition;
	private final Position namePosition;
	private final Set<CAstEntity> entities;
	
	public ContractEntity(CAstType.Class type, Position sourcePosition, Position namePosition, Set<CAstEntity> entities) {
		super(type);
		this.namePosition = namePosition;
		this.sourcePosition = sourcePosition;
		this.entities = entities;
	}
	
	@Override
	public Map<CAstNode, Collection<CAstEntity>> getAllScopedEntities() {
		return Collections.singletonMap(null, entities);
	}

	@Override
	public Collection<CAstAnnotation> getAnnotations() {
		// TODO Auto-generated method stub
		return null;
	}


	@Override
	public Position getNamePosition() {
		return namePosition;
	}

	@Override
	public Position getPosition() {
		return sourcePosition;
	}

	@Override
	public Collection<CAstQualifier> getQualifiers() {
		return ((CAstType.Class)getType()).getQualifiers();
	}

	@Override
	public Iterator<CAstEntity> getScopedEntities(CAstNode construct) {
		if (construct == null) {
			return entities.iterator();
		} else {
			return EmptyIterator.instance();
		}
	}

	@Override
	public Position getPosition(int arg) {
		// TODO Auto-generated method stub
		return null;
	}
}
