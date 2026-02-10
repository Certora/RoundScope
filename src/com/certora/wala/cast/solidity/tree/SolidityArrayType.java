package com.certora.wala.cast.solidity.tree;

import java.util.Collection;
import java.util.Collections;
import java.util.Map;

import com.ibm.wala.cast.tree.CAstType;
import com.ibm.wala.types.TypeReference;
import com.ibm.wala.util.collections.HashMapFactory;

public class SolidityArrayType implements CAstType {
	private final CAstType eltType;
	
	public SolidityArrayType(CAstType eltType) {
		this.eltType = eltType;
	}

	@Override
	public String getName() {
		return eltType.getName() + "[]";
	}

	@Override
	public Collection<CAstType> getSupertypes() {
		return Collections.singleton(SolidityCAstType.get("array"));
	}

	private static Map<CAstType, SolidityArrayType> types = HashMapFactory.make();
	
	public static CAstType get(CAstType elt) {
		if (types.containsKey(elt)) {
			return types.get(elt);
		} else {
			SolidityArrayType type = new SolidityArrayType(elt);
			
			TypeReference irType = SolidityCAstType.getIRType(elt).getArrayTypeForElementType();
			
			SolidityCAstType.record(type.getName(), type, irType);
			types.put(elt, type);
			return type;
		}
		
	}
 }
