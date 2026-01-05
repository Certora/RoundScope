package com.certora.wala.cast.solidity.tree;

import java.util.Collection;
import java.util.Collections;
import java.util.List;
import java.util.Map;

import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.ibm.wala.cast.tree.CAstType;
import com.ibm.wala.cast.tree.CAstType.Function;
import com.ibm.wala.types.TypeReference;
import com.ibm.wala.util.collections.HashMapFactory;
import com.ibm.wala.util.collections.Pair;

public class SolidityMappingType implements Function {
	private final CAstType keyType;
	private final CAstType valueType;
	
	public SolidityMappingType(CAstType keyType, CAstType valueType) {
		this.keyType = keyType;
		this.valueType = valueType;
	}

	@Override
	public String getName() {
		return "mapping(" + keyType.getName() + " => " + valueType.getName();
	}

	@Override
	public Collection<CAstType> getSupertypes() {
		return Collections.singleton(SolidityCAstType.get("mapping"));
	}

	@Override
	public int getArgumentCount() {
		return 1;
	}

	@Override
	public List<CAstType> getArgumentTypes() {
		return Collections.singletonList(keyType);
	}

	@Override
	public Collection<CAstType> getExceptionTypes() {
		return null;
	}

	@Override
	public CAstType getReturnType() {
		return valueType;
	}

	private static Map<Pair<CAstType,CAstType>, SolidityMappingType> types = HashMapFactory.make();
	
	public static CAstType get(CAstType key, CAstType value) {
		Pair<CAstType,CAstType> typeKey = Pair.make(key, value);
		if (types.containsKey(typeKey)) {
			return types.get(typeKey);
		} else {
			SolidityMappingType type = new SolidityMappingType(key, value);
			
			TypeReference irType = TypeReference.findOrCreate(SolidityTypes.solidity, "mapping<" + key.getName() + "#" + value.getName() + ">");
			
			SolidityCAstType.record(type.getName(), type, irType);
			types.put(typeKey, type);
			return type;
		}
		
	}
 }
