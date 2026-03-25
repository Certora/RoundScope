package com.certora.wala.cast.solidity.json;

import com.ibm.wala.cast.tree.CAstEntity;

interface VariableContainerContext extends SolidityWalkContext {
	@Override
	default void registerVariable(String name, CAstEntity field) {
		variables().add(field);
	}

}
