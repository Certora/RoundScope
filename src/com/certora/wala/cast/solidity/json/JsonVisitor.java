package com.certora.wala.cast.solidity.json;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;

import org.json.JSONException;
import org.json.JSONObject;

public interface JsonVisitor<R, S> {

	public String key(JSONObject o);
	
	public Class<S> context();

	default R visitNode(JSONObject o, S context) {
		return null;
	}

	@SuppressWarnings("unchecked")
	default R visit(JSONObject o, S context) {
		try {
			Method vm = this.getClass().getMethod("visit" + o.getString(key(o)), JSONObject.class,
					context());
			return (R) vm.invoke(this, o, context);
		} catch (NoSuchMethodException | SecurityException | IllegalAccessException | InvocationTargetException | JSONException e) {
			return visitNode(o, context);
		}
	}

}
