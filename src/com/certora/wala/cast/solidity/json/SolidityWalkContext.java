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
package com.certora.wala.cast.solidity.json;

import java.util.Collection;
import java.util.Map;

import org.json.JSONObject;

import com.ibm.wala.cast.ir.translator.TranslatorToCAst;
import com.ibm.wala.cast.tree.CAstEntity;
import com.ibm.wala.cast.tree.CAstType;

public interface SolidityWalkContext extends TranslatorToCAst.WalkContext<SolidityWalkContext, JSONObject> {

	default SolidityWalkContext parent() {
		return (SolidityWalkContext) getParent();
	}
	
	default Collection<CAstEntity> variables() {
		return parent().variables();
	}
	
	default void registerVariable(String name, CAstEntity field) {
		parent().registerVariable(name, field);
	}
	
	default Collection<CAstEntity> functions() {
		return parent().functions();
	}
	
	default void registerFunction(String name, CAstEntity field) {
		parent().registerVariable(name, field);
	}
	
	default JSONObject contract() {
		return parent().contract();
	}

	default CAstType type() {
		return parent().type();
	}

	default JSONObject sourceUnit() {
		return parent().sourceUnit();
	}

	default JSONObject sourceUnit(int nodeId) {
		return parent().sourceUnit();
	}
	
	default Map<String,JSONObject> renamings() {
		return parent().renamings();
	}
}
