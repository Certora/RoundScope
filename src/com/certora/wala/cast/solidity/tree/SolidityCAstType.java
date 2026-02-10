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
	public static final Map<CAstType,TypeReference> irTypes = HashMapFactory.make();
	
	static {
		for(Object[] nm : new Object[][] {
			{"library", SolidityTypes.library},
			{"contract", SolidityTypes.contract},
			{"abi", SolidityTypes.abi},
			{"enum", SolidityTypes.enm},
			{"address", SolidityTypes.address},
			{"string", SolidityTypes.string},
			{"bool", SolidityTypes.bool},
			{"function", SolidityTypes.function},
			{"struct", SolidityTypes.struct},
			{"bytes", SolidityTypes.bytes},
			{"bytes32", SolidityTypes.bytes32},
			{"bytes4", SolidityTypes.bytes4},
			{"bytes16", SolidityTypes.bytes16},
			{"bytes1", SolidityTypes.bytes1},
			{"error", SolidityTypes.error},
			{"msg", SolidityTypes.msg},
			{"void", TypeReference.Void}}) {
			CAstType t = new SolidityCAstType((String)nm[0]);
			types.put((String)nm[0], t);
			irTypes.put(t, (TypeReference)nm[1]);
		}
		try {
			for(int i = 8; i <= 256; i += 8) {
				TypeReference ut = (TypeReference) SolidityTypes.class.getField("uint" + i).get(null);
				SolidityCAstType t = new SolidityCAstType("uint" + i);
				types.put("uint" + i, t);
				irTypes.put(t, ut);

				TypeReference it = (TypeReference) SolidityTypes.class.getField("int" + i).get(null);
				SolidityCAstType ti = new SolidityCAstType("int" + i);
				types.put("int" + i, ti);
				irTypes.put(ti, it);

			}
		} catch (NoSuchFieldException | SecurityException | IllegalArgumentException | IllegalAccessException e) {
			assert false : e;
		}
	}
	
	public static void record(String name, CAstType type, TypeReference irType) {
		assert !types.containsKey(name);
		if (irType.toString().contains("contract.decimals")) {
			System.err.println(name + ":" + type);
		}
		types.put(name, type);
		irTypes.put(type, irType);
	}
	
	public static CAstType get(String name) {
		if (!types.containsKey(name) && name.startsWith("type(")) {
			return get(name.substring(5, name.length()-1));
		} else if (!types.containsKey(name) && name.contains(" ")) {
			return get(name.split(" ")[0]);
		}
		if (!types.containsKey(name)) {
			System.err.println("cannot find type " + name);
		}
		return types.get(name);
	}

	public static TypeReference getIRType(CAstType name) {
		return irTypes.get(name);
	}
}
