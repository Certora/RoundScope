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

import java.io.File;
import java.util.Map;

import com.ibm.wala.classLoader.IClassLoader;
import com.ibm.wala.ipa.cha.IClassHierarchy;

public class SolidityJNILoaderFactory extends SolidityLoaderFactory {
	protected final Map<String, File> includePath;
	protected File confFile;

	public SolidityJNILoaderFactory(File confFile, Map<String, File> includePath) {
		this.confFile = confFile;
		this.includePath = includePath;
	}

	@Override
	protected IClassLoader makeTheLoader(IClassHierarchy cha) {
		return new SolidityJNILoader(confFile, includePath, cha, null);
	}
}
