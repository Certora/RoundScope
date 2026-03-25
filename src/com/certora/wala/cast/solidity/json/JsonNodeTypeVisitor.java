package com.certora.wala.cast.solidity.json;

import org.json.JSONObject;

public interface JsonNodeTypeVisitor<R, S> extends JsonVisitor<R, S>{
	
	default public String key(JSONObject o) {
		return "nodeType";
	}

}
