package com.certora.wala.cast.solidity.json;

import java.util.Map;

import org.json.JSONObject;

import com.ibm.wala.cast.ir.translator.TranslatorToCAst;
import com.ibm.wala.cast.tree.CAstEntity;
import com.ibm.wala.cast.tree.CAstType;

public interface SolidityWalkContext extends TranslatorToCAst.WalkContext<SolidityWalkContext, JSONObject> {

	default SolidityWalkContext parent() {
		return (SolidityWalkContext) getParent();
	}
	
	default Map<String,CAstEntity> variables() {
		return parent().variables();
	}
	
	default void registerVariable(String name, CAstEntity field) {
		parent().registerVariable(name, field);
	}
	
	default Map<String,CAstEntity> functions() {
		return parent().variables();
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
}
