package com.certora.wala.cast.solidity.json;

public class JSONCAstRunner {

	public static void main(String... args) throws Exception {
		new JSONToCAst(null).translateFiles(args[0]);
	}
	
}
