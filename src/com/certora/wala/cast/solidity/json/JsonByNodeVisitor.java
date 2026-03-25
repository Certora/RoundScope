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
