/*
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License v. 2.0 which is available at
 * http://eclipse.org.
 *
 * This Source Code may also be made available under the following Secondary
 * Licenses when the conditions for such availability set forth in the Eclipse
 * Public License, v. 2.0 are satisfied: {name license(s), version(s), and
 * exceptions or additional permissions here}.
 *
 * SPDX-License-Identifier: EPL-2.0
 */
package com.certora.wala.cast.solidity.loader;

import java.util.Collection;
import java.util.Map;

import com.ibm.wala.cast.loader.AstClass;
import com.ibm.wala.cast.tree.CAstSourcePositionMap.Position;
import com.ibm.wala.classLoader.IClass;
import com.ibm.wala.classLoader.IClassLoader;
import com.ibm.wala.classLoader.IField;
import com.ibm.wala.classLoader.IMethod;
import com.ibm.wala.core.util.strings.Atom;
import com.ibm.wala.ipa.cha.IClassHierarchy;
import com.ibm.wala.types.Selector;
import com.ibm.wala.types.TypeName;
import com.ibm.wala.types.annotations.Annotation;

public class Contract extends AstClass {

	protected Contract(Position sourcePosition, TypeName typeName, IClassLoader loader, short modifiers,
			Map<Atom, IField> declaredFields, Map<Selector, IMethod> declaredMethods) {
		super(sourcePosition, typeName, loader, modifiers, declaredFields, declaredMethods);
		// TODO Auto-generated constructor stub
	}

	@Override
	public Collection<Annotation> getAnnotations() {
		// TODO Auto-generated method stub
		return null;
	}

	@Override
	public IClassHierarchy getClassHierarchy() {
		// TODO Auto-generated method stub
		return null;
	}

	@Override
	public Collection<IClass> getDirectInterfaces() {
		// TODO Auto-generated method stub
		return null;
	}

	@Override
	public IClass getSuperclass() {
		// TODO Auto-generated method stub
		return null;
	}

}
