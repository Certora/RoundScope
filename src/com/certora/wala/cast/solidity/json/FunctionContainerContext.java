package com.certora.wala.cast.solidity.json;

import com.ibm.wala.cast.tree.CAstEntity;

interface FunctionContainerContext extends SolidityWalkContext {
	@Override
	default void registerFunction(String name, CAstEntity field) {
		functions().put(name, field);
	}
}