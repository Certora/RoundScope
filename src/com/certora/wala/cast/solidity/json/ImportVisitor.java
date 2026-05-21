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
package com.certora.wala.cast.solidity.json;

import org.json.JSONObject;

import com.ibm.wala.util.intset.IntSetUtil;
import com.ibm.wala.util.intset.MutableIntSet;

public class ImportVisitor implements JsonByNodeVisitor {
	public final MutableIntSet imports = IntSetUtil.make();
	public final MutableIntSet aliased = IntSetUtil.make();
				
	@SuppressWarnings("unused")
	public Void visitImportDirective(JSONObject o, Void context) {
		imports.add(o.getInt("sourceUnit"));
		if (o.has("unitAlias") && !"".equals(o.get("unitAlias"))) {
			aliased.add(o.getInt("sourceUnit"));
		}
		return null;
	}
}
