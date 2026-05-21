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
package com.certora.wala.cast.solidity.jni;

import java.util.Set;

import com.ibm.wala.cast.tree.CAstEntity;
import com.ibm.wala.cast.util.CAstPrinter;
import com.ibm.wala.util.collections.HashSetFactory;

public class JNICAstRunner {
	public static void main(String... args) throws Exception {
		Set<CAstEntity> ces = HashSetFactory.make();
		try (SolidityJNIBridge test = new SolidityJNIBridge(null)) {
			test.loadFiles(args);
			System.out.println(test.files());
			for (String f : test.files()) {
				ces.add(test.translateFile(f));
			};
			System.out.println("entities:");
			ces.forEach(ce -> System.out.println(CAstPrinter.print(ce)));
		} catch (Exception e) {
			throw e;
			
		}
	}
}
