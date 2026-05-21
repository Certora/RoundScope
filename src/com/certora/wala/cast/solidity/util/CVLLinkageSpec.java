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

import java.util.List;
import java.util.Map;

import org.eclipse.lsp4j.jsonrpc.messages.Either;

import com.ibm.wala.core.util.strings.Atom;
import com.ibm.wala.types.TypeReference;
import com.ibm.wala.util.collections.Pair;

public interface CVLLinkageSpec {

	Map<Pair<List<Either<Atom,Integer>>,TypeReference>,TypeReference> getLink();
}
