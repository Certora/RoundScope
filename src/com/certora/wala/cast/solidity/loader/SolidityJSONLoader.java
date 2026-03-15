package com.certora.wala.cast.solidity.loader;

import java.io.IOException;
import java.util.List;

import org.json.JSONObject;
import org.json.JSONTokener;

import com.certora.wala.cast.solidity.json.JSONToCAst;
import com.ibm.wala.cast.ir.translator.TranslatorToCAst;
import com.ibm.wala.cast.tree.CAst;
import com.ibm.wala.classLoader.IClassLoader;
import com.ibm.wala.classLoader.Module;
import com.ibm.wala.classLoader.ModuleEntry;
import com.ibm.wala.ipa.cha.IClassHierarchy;

public class SolidityJSONLoader extends SolidityLoader {
	JSONToCAst solidityCode = new JSONToCAst();
	
	public SolidityJSONLoader(IClassHierarchy cha, IClassLoader parent) {
		super(cha, parent);
	}

	@Override
	protected TranslatorToCAst getTranslatorToCAst(CAst ast, ModuleEntry M, List<Module> modules) throws IOException {
		JSONTokener toks = new JSONTokener(M.getInputStream());
		return solidityCode.new SolidityJSONTranslator((JSONObject) toks.nextValue());
	}

	
}
