package com.certora.wala.cast.solidity.types;

import com.ibm.wala.core.util.strings.Atom;
import com.ibm.wala.types.ClassLoaderReference;
import com.ibm.wala.types.TypeReference;

public class SolidityTypes {

	public static Atom solidityLanguage = Atom.findOrCreateUnicodeAtom("Solidity");
	
	public static ClassLoaderReference solidity = new ClassLoaderReference(Atom.findOrCreateUnicodeAtom("solidity"), solidityLanguage, null);
	
	public static TypeReference root = TypeReference.findOrCreate(solidity, "Lroot");

	public static TypeReference exception = TypeReference.findOrCreate(solidity, "Lexception");

	public static TypeReference contract = TypeReference.findOrCreate(solidity, "Lcontract");

	public static TypeReference msg = TypeReference.findOrCreate(solidity, "Lmsg");

	public static TypeReference codeBody = TypeReference.findOrCreate(solidity, "LCodeBody");

	public static TypeReference function = TypeReference.findOrCreate(solidity, "Lfunction");

	public static TypeReference event = TypeReference.findOrCreate(solidity, "Levent");

	public static TypeReference uint8 = TypeReference.findOrCreate(solidity, "Puint8");

	public static TypeReference uint256 = TypeReference.findOrCreate(solidity, "Puint256");

	public static TypeReference address = TypeReference.findOrCreate(solidity, "Paddress");

	public static TypeReference string = TypeReference.findOrCreate(solidity, "Pstring");

	public static TypeReference bool = TypeReference.findOrCreate(solidity, "Pbool");

}
