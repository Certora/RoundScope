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
package com.certora.wala.cast.solidity.util;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.eclipse.lsp4j.jsonrpc.messages.Either;
import org.json.JSONArray;
import org.json.JSONObject;
import org.json.JSONTokener;

import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.google.common.collect.Streams;
import com.ibm.wala.core.util.strings.Atom;
import com.ibm.wala.types.TypeReference;
import com.ibm.wala.util.WalaRuntimeException;
import com.ibm.wala.util.collections.HashMapFactory;
import com.ibm.wala.util.collections.Pair;

public class SpecFileJSON implements CVLLinkageSpec {
	private final JSONObject ast;
	
	public SpecFileJSON(String cvlJsonFile) throws FileNotFoundException {
		this(new File(cvlJsonFile));
	}
	
	public SpecFileJSON(File cvlJsonFile) throws FileNotFoundException {
		JSONTokener json = new JSONTokener(new FileReader(cvlJsonFile));
		ast = (JSONObject) json.nextValue();
	}

	public Map<Pair<List<Either<Atom,Integer>>,TypeReference>,TypeReference> getLink() {
		if (ast.has("linkEntries")) {
			Map<Pair<List<Either<Atom,Integer>>,TypeReference>,TypeReference> links = HashMapFactory.make();
			
			Map<String,String> nameAliases = HashMapFactory.make();
			if (ast.has("importedContracts")) {
				JSONArray map = ast.getJSONArray("importedContracts");
				Streams.stream(map.iterator()).map(x -> (JSONObject)x).forEach(e -> { 
					String var = e.getString("solidityContractVarId");
					String type = e.getJSONObject("solidityContractName").getString("name");
					nameAliases.put(var, type);
				});
			}			
			
			Streams.stream(ast.getJSONArray("linkEntries").iterator()).map(x -> (JSONObject)x).forEach(entry -> { 
				TypeReference container = TypeReference.findOrCreate(SolidityTypes.solidity, "Lcontract " + nameAliases.get(entry.getString("sourceContractAlias")));
				
				List<Either<Atom,Integer>> fields = Streams.stream(entry.getJSONArray("fieldPath").iterator()).map(x -> (JSONObject)x).map(f -> {
					switch (f.getString("type")) {
					case "spec.cvlast.CVLLinkPathSegment.Field":
						String name = f.getString("name");
						return Either.<Atom,Integer>forLeft(Atom.findOrCreateUnicodeAtom(name));
					case "spec.cvlast.CVLLinkPathSegment.Index":
						Integer idx = Integer.valueOf(f.getJSONObject("value").getString("value"));
						return Either.<Atom,Integer>forRight(idx);
					}
					throw new WalaRuntimeException("unexpected " + f);
				}).collect(Collectors.toList());
				
				List<TypeReference> targets = Streams.stream(entry.getJSONArray("targets").iterator()).map(x -> (String)x).map(target -> 
					TypeReference.findOrCreate(SolidityTypes.solidity, "Lcontract " + nameAliases.get(target))
				).collect(Collectors.toList());
				
				targets.forEach(t -> { 
					links.put(Pair.make(fields, container), t);
				});
			});
			
			return links;
			
		} else {
			return Collections.emptyMap();
		}
	}	
}
