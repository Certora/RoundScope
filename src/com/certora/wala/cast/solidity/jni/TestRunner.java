package com.certora.wala.cast.solidity.jni;

import java.util.Set;

import com.ibm.wala.cast.tree.CAstEntity;
import com.ibm.wala.cast.util.CAstPrinter;
import com.ibm.wala.util.collections.HashSetFactory;

public class TestRunner {
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
