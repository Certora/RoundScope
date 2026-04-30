package com.certora.wala.cast.solidity.util;

import java.util.List;
import java.util.Map;

import org.eclipse.lsp4j.jsonrpc.messages.Either;

import com.ibm.wala.core.util.strings.Atom;
import com.ibm.wala.types.TypeReference;
import com.ibm.wala.util.collections.Pair;

public interface CVLLinkageSpec {

	Map<Pair<List<Either<Atom,Integer>>,TypeReference>,TypeReference> getLink();
}
