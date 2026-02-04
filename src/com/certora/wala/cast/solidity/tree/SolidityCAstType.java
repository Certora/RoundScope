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
			{"library", SolidityTypes.library},
			{"enum", SolidityTypes.enm},
			{"address", SolidityTypes.address},
			{"string", SolidityTypes.string},
			{"bool", SolidityTypes.bool},
			{"function", SolidityTypes.function},
			{"struct", SolidityTypes.struct},
			{"bytes", SolidityTypes.bytes},
			{"bytes32", SolidityTypes.bytes32},
			{"bytes4", SolidityTypes.bytes4},
			{"error", SolidityTypes.error},
			{"msg", SolidityTypes.msg},
			{"void", TypeReference.Void}}) {
			types.put((String)nm[0], new SolidityCAstType((String)nm[0]));
			irTypes.put((String)nm[0], (TypeReference)nm[1]);
		}
		try {
			for(int i = 8; i <= 256; i += 8) {
				TypeReference ut = (TypeReference) SolidityTypes.class.getField("uint" + i).get(null);
				types.put("uint" + i, new SolidityCAstType("uint" + i));
				irTypes.put("uint" + i, ut);

				TypeReference it = (TypeReference) SolidityTypes.class.getField("int" + i).get(null);
				types.put("int" + i, new SolidityCAstType("int" + i));
				irTypes.put("int" + i, it);

			}
		} catch (NoSuchFieldException | SecurityException | IllegalArgumentException | IllegalAccessException e) {
			assert false : e;
		}
	}
	
	public static void record(String name, CAstType type, TypeReference irType) {
		assert !types.containsKey(name);
		types.put(name, type);
		irTypes.put(name, irType);
	}
	
	public static CAstType get(String name) {
		if (!types.containsKey(name) && name.startsWith("type(")) {
			return get(name.substring(5, name.length()-1));
		} else if (!types.containsKey(name) && name.contains(" ")) {
			return get(name.split(" ")[0]);
		}
		assert types.containsKey(name) : name;
		return types.get(name);
	}

	public static TypeReference getIRType(String name) {
		return irTypes.get(name);
	}
}
