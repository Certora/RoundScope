package com.certora.wala.cast.solidity.tree;

import java.util.Collection;
import java.util.Map;

import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.ibm.wala.cast.tree.CAstType;
import com.ibm.wala.types.TypeReference;
import com.ibm.wala.util.collections.HashMapFactory;

public class SolidityCAstType implements CAstType.Primitive {

	private final String name;

	private SolidityCAstType(String name) {
		this.name = name;
	}
	
	@Override
	public String getName() {
		return name;
	}

	@Override
	public Collection<CAstType> getSupertypes() {
		return null;
	}

	@Override
	public String toString() {
		return "<" + name + ">";
	}
	
	public static final Map<String,CAstType> types = HashMapFactory.make();
	public static final Map<String,TypeReference> irTypes = HashMapFactory.make();
	
	static {
		for(Object[] nm : new Object[][] {
				{"uint8", SolidityTypes.uint8},
				{"uint64", SolidityTypes.uint64},
				{"uint256", SolidityTypes.uint256},
				{"address", SolidityTypes.address},
				{"string", SolidityTypes.string},
				{"bool", SolidityTypes.bool},
				{"function", SolidityTypes.function},
				{"struct", SolidityTypes.struct},
				{"bytes32", SolidityTypes.bytes32},
				{"bytes4", SolidityTypes.bytes4},
				{"error", SolidityTypes.error},
				{"msg", SolidityTypes.msg},
				{"void", TypeReference.Void}}) {
			types.put((String)nm[0], new SolidityCAstType((String)nm[0]));
			irTypes.put((String)nm[0], (TypeReference)nm[1]);
		}
	}
	
	public static void record(String name, CAstType type, TypeReference irType) {
		assert !types.containsKey(name);
		types.put(name, type);
		irTypes.put(name, irType);
	}
	
	public static CAstType get(String name) {
//		assert types.containsKey(name) : name;
		return types.get(name);
	}

	public static TypeReference getIRType(String name) {
		return irTypes.get(name);
	}
}
