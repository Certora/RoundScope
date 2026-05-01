package com.certora.wala.cast.solidity.test;

import java.io.File;
import java.io.FileNotFoundException;
import java.util.Collections;
import java.util.List;
import java.util.Map;

import org.eclipse.lsp4j.jsonrpc.messages.Either;
import org.jspecify.annotations.NonNull;
import org.junit.jupiter.api.Test;

import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.certora.wala.cast.solidity.util.SpecFileJSON;
import com.ibm.wala.core.util.strings.Atom;
import com.ibm.wala.types.TypeReference;
import com.ibm.wala.util.collections.Pair;

public class TestSpecFileJSON {

	@Test
	public void testBasicLinking() throws FileNotFoundException {
		File bl = new File("test/data/BasicLinking.json");
		SpecFileJSON s = new SpecFileJSON(bl);
		Map<Pair<List<Either<Atom, Integer>>, TypeReference>, TypeReference> l = s.getLink();
		System.err.println(l);
		Pair<List<Either<@NonNull Atom, Object>>, TypeReference> key = Pair.make(Collections.singletonList(Either.forLeft(Atom.findOrCreateUnicodeAtom("primaryToken"))), TypeReference.findOrCreate(SolidityTypes.solidity, "Lcontract BasicVault"));
		assert l.containsKey(key);
		assert l.get(key).equals(TypeReference.findOrCreate(SolidityTypes.solidity, "Lcontract TokenA"));
	}
	
}
