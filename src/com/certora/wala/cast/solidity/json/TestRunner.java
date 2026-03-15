package com.certora.wala.cast.solidity.json;

public class TestRunner {

	public static void main(String... args) throws Exception {
		new JSONToCAst().translateFiles(args[0]);
	}
	
}
