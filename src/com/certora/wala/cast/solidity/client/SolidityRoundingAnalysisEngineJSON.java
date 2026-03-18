package com.certora.wala.cast.solidity.client;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.Reader;
import java.net.URL;
import java.util.Arrays;
import java.util.Collections;
import java.util.Iterator;
import java.util.Set;

import org.json.JSONArray;
import org.json.JSONObject;
import org.json.JSONTokener;

import com.certora.wala.cast.solidity.json.JsonNodeTypeOnlyVisitor;
import com.certora.wala.cast.solidity.loader.SolidityJSONLoaderFactory;
import com.certora.wala.cast.solidity.loader.SolidityLoader;
import com.certora.wala.cast.solidity.loader.SolidityLoaderFactory;
import com.certora.wala.classLoader.SourceJSONModule;
import com.google.common.collect.Streams;
import com.ibm.wala.cast.ipa.callgraph.CAstAnalysisScope;
import com.ibm.wala.classLoader.Module;
import com.ibm.wala.classLoader.ModuleEntry;
import com.ibm.wala.classLoader.SourceFileModule;
import com.ibm.wala.util.collections.HashSetFactory;
import com.ibm.wala.util.collections.NonNullSingletonIterator;
import com.ibm.wala.util.config.StringFilter;

public class SolidityRoundingAnalysisEngineJSON extends SolidityRoundingAnalysisEngine {
	private final Module[] jsons;
	
	public SolidityRoundingAnalysisEngineJSON(File confFile, String[] jsonFileNames) throws FileNotFoundException {
		super(confFile);
		jsons = Arrays.stream(jsonFileNames).map(f -> new SourceFileModule(new File(f), f, null)).toArray(i -> new Module[i]);
	}

	public static class JsonSourceUnits implements JsonNodeTypeOnlyVisitor<Void> {
		private final Set<JSONObject> sources = HashSetFactory.make();
		
		@SuppressWarnings("unused")
		public Void visitSourceUnit(JSONObject o, Void context) {
			sources.add(o);
			visitChildren(o);
			return null;
		}

		@Override
		public Void visitNode(JSONObject o, Void context) {
			visitChildren(o);
			return null;
		}
		
		private void visitChildren(JSONObject o) {
			for(String k : o.keySet()) {
				if ("2330".equals(k)) {
					System.err.println(k);
				}
				Object v = o.get(k);
				if (v instanceof JSONObject) {
					visit((JSONObject)v, null);
				} else if (v instanceof JSONArray) {
					Streams.stream(((JSONArray)v).iterator()).forEach(e -> {
						if (e instanceof JSONObject) {
							visit((JSONObject)e, null);								
						}
					});
				}
			}
		}
	}
	
	public SolidityRoundingAnalysisEngineJSON(File confFile, String solidityJsonFileName) throws FileNotFoundException {
		super(confFile);
		JSONObject o = (JSONObject) new JSONTokener(new FileReader(solidityJsonFileName)).nextValue();
		JsonSourceUnits v = new JsonSourceUnits();
		v.visit(o, null);
		jsons = v.sources.stream().map(f -> 
			new SourceJSONModule() {

				@Override
				public Reader getInputReader() {
					return null;
				}

				@Override
				public URL getURL() {
					// TODO Auto-generated method stub
					return null;
				}

				@Override
				public Iterator<? extends ModuleEntry> getEntries() {
					return new NonNullSingletonIterator<>(this);
				}

				@Override
				public String getName() {
					return f.getString("absolutePath");
				}

				@Override
				public boolean isClassFile() {
					return false;
				}

				@Override
				public boolean isSourceFile() {
					return true;
				}

				@Override
				public InputStream getInputStream() {
					// TODO Auto-generated method stub
					return null;
				}

				@Override
				public boolean isModuleFile() {
					return false;
				}

				@Override
				public Module asModule() {
					return null;
				}

				@Override
				public String getClassName() {
					return getName();
				}

				@Override
				public Module getContainer() {
					return null;
				}

				@Override
				public JSONObject getJSON() {
					return f;
				} 	
				
				public String toString() {
					return "<module for " + getName() + ">";
				}
			}).toArray(i -> new Module[i]);
	}
	
	@Override
	protected SolidityLoaderFactory makeClassLoaderFactory(StringFilter exclusions) {
		return new SolidityJSONLoaderFactory();
	}

	@Override
	public void buildAnalysisScope() throws IOException {
		loaders = makeClassLoaderFactory(null); 

		scope = new CAstAnalysisScope(jsons, loaders,
				Collections.singleton(SolidityLoader.solidity));
	}

	
}
