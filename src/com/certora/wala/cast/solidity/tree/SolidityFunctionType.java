package com.certora.wala.cast.solidity.tree;

import java.util.Collection;
import java.util.Collections;

import com.ibm.wala.cast.tree.CAstType;

public class SolidityFunctionType implements CAstType {
	private final String name;
	private final CAstType[] parameters;
	private final CAstType[] returns;
	private final boolean event;

	public SolidityFunctionType(String name, CAstType[] parameters, CAstType[] returns, boolean event) {
		this.name = name;
		this.parameters = parameters;
		this.returns = returns;
		this.event = event;
	}

	@Override
	public String getName() {
		return name;
	}

	public CAstType[] parameters() {
		return parameters;
	}

	public CAstType[] returns() {
		return returns;
	}
	
	public boolean isEvent() {
		return event;
	}
	
	@Override
	public Collection<CAstType> getSupertypes() {
		return Collections.emptySet();
	}

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
	
	@Override
	public String toString() {
		String s = (isEvent()? "event ": "function ") + name + arrayToString(parameters);
		if (returns != null && returns.length > 0) {
			s += " --> " + arrayToString(returns);
		}
		return s;
	}
}
