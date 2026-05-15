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
