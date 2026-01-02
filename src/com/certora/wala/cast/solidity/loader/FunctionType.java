package com.certora.wala.cast.solidity.loader;

import java.util.Arrays;
import java.util.Collection;
import java.util.Collections;
import java.util.List;

import com.certora.wala.cast.solidity.tree.SolidityCAstType;
import com.certora.wala.cast.solidity.tree.SolidityFunctionType;
import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.ibm.wala.cast.tree.CAstType;
import com.ibm.wala.cast.tree.CAstType.Function;
import com.ibm.wala.types.Descriptor;
import com.ibm.wala.types.TypeName;
import com.ibm.wala.types.TypeReference;

public class FunctionType implements Function {

	private final String name;
	private final CAstType returnType;
	private CAstType[] args;

	public FunctionType(String name, CAstType returnType, CAstType... args) {
		this.returnType = returnType==null? SolidityCAstType.get("void"): returnType;
		this.args = args;
		
		String sig = name + " " + SolidityFunctionType.arrayToString(args);
		if (returnType != null) {
			sig += " --> " + returnType.getName();
		}
		
		TypeReference tr = TypeReference.findOrCreate(SolidityTypes.solidity, sig);
		SolidityCAstType.record(sig, this, tr);
		
		this.name = sig;
	}
	
	@Override
	public String getName() {
		return name;
	}

	@Override
	public Collection<CAstType> getSupertypes() {
		return Collections.singleton(SolidityCAstType.get("root"));
	}

	@Override
	public int getArgumentCount() {
		return args.length;
	}

	@Override
	public List<CAstType> getArgumentTypes() {
		return Arrays.asList(args);
	}

	@Override
	public Collection<CAstType> getExceptionTypes() {
		return Collections.emptySet();
	}

	@Override
	public CAstType getReturnType() {
		return returnType;
	}

}
