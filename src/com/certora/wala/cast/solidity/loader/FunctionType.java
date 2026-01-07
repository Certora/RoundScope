package com.certora.wala.cast.solidity.loader;

import java.util.Arrays;
import java.util.Collection;
import java.util.Collections;
import java.util.List;

import com.certora.wala.cast.solidity.tree.SolidityCAstType;
import com.certora.wala.cast.solidity.tree.SolidityFunctionType;
import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.ibm.wala.cast.tree.CAstType;
import com.ibm.wala.cast.tree.CAstType.Method;
import com.ibm.wala.types.TypeReference;

public class FunctionType implements Method {

	private final String name;
	private final CAstType returnType;
	private final CAstType[] args;
	private final CAstType self;

	public static String arrayToString(CAstType[] parameters) {
		if (parameters != null && parameters.length > 0) {
			String s = "(" + parameters[0].getName();
			if (parameters.length > 1) {
				for(int i = 1; i < parameters.length; i++) {
					s += "," + parameters[i].getName();
				}
			}
			s += ")";
			return s;
		} else {
			return "";
		}
	}

	public static String signature(String name, CAstType[] args, CAstType returnType) {
		String sig = name + " " + arrayToString(args);
		if (returnType != null) {
			sig += " --> " + returnType.getName();
		}
		return sig;
	}
	
	public FunctionType(String name, CAstType self, CAstType returnType, CAstType... args) {
		this.name = name;
		this.returnType = returnType==null? SolidityCAstType.get("void"): returnType;
		this.args = args;
		this.self = self;
		
		String sig = signature(name, args, returnType);
		
		TypeReference tr = TypeReference.findOrCreate(SolidityTypes.solidity, sig);
		SolidityCAstType.record(sig, this, tr);
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

	@Override
	public CAstType getDeclaringType() {
		return self;
	}

	@Override
	public boolean isStatic() {
		return false;
	}

}
