package com.certora.wala.cast.solidity.tree;

import java.util.Arrays;
import java.util.Collection;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.ibm.wala.cast.tree.CAstType;
import com.ibm.wala.types.TypeReference;
import com.ibm.wala.util.collections.HashMapFactory;

public class SolidityTupleType implements CAstType {
	private final List<CAstType> valueTypes;
	
	public SolidityTupleType(CAstType... valueTypes) {
		this.valueTypes = Arrays.asList(valueTypes);
	}

	public CAstType getElement(int i) {
		return valueTypes.get(i);
	}
	
	@Override
	public String getName() {
		return "tuple(" + valueTypes.stream().map(t -> t.getName()).reduce((a, b) -> a + "," + b).orElse("") + ")";
	}

	@Override
	public Collection<CAstType> getSupertypes() {
		return Collections.singleton(SolidityCAstType.get("tuple"));
	}

	private static Map<List<CAstType>, SolidityTupleType> types = HashMapFactory.make();
	
	public static CAstType get(CAstType[] values) {
		List<CAstType> typeKey = Arrays.asList(values).stream().map(x -> x==null? SolidityCAstType.get("root"): x).collect(Collectors.toList());
		if (types.containsKey(typeKey)) {
			return types.get(typeKey);
		} else {
			SolidityTupleType type = new SolidityTupleType(typeKey.toArray(new CAstType[typeKey.size()]));
			
			TypeReference irType = TypeReference.findOrCreate(SolidityTypes.solidity, type.getName());
			
			SolidityCAstType.record(type.getName(), type, irType);
			types.put(typeKey, type);
			return type;
		}
		
	}
 }
