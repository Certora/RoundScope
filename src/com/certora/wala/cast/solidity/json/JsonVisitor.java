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
