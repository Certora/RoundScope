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

import org.json.JSONArray;
import org.json.JSONObject;

public interface JsonByNodeVisitor extends JsonNodeTypeOnlyVisitor<Void> {
	
	@Override
	default Void visitNode(JSONObject o, Void context) {
		for(String key : o.keySet()) {
			Object v = o.get(key);
			if (v instanceof JSONObject) {
				visit((JSONObject)v, null);
			} else if (v instanceof JSONArray) {
				for(Object vv: (JSONArray)v) {
					if (vv instanceof JSONObject)
						visit((JSONObject)vv, null);
				}
			}
		}
		return null;
	}
	
}
