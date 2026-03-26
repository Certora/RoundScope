package com.certora.wala.cast.solidity.loader;

import java.io.IOException;
import java.util.Collection;
import java.util.List;
import java.util.Map;

import org.json.JSONObject;
import org.json.JSONTokener;

import com.certora.wala.cast.solidity.json.ImportVisitor;
import com.certora.wala.cast.solidity.json.JSONToCAst;
import com.certora.wala.classLoader.SourceJSONModule;
import com.google.common.collect.Streams;
import com.ibm.wala.cast.ir.translator.TranslatorToCAst;
import com.ibm.wala.cast.tree.CAst;
import com.ibm.wala.classLoader.IClassLoader;
import com.ibm.wala.classLoader.Module;
import com.ibm.wala.classLoader.ModuleEntry;
import com.ibm.wala.ipa.cha.IClassHierarchy;
import com.ibm.wala.util.collections.HashMapFactory;
import com.ibm.wala.util.graph.Graph;
import com.ibm.wala.util.graph.impl.SlowSparseNumberedGraph;
import com.ibm.wala.util.graph.traverse.Topological;
import com.ibm.wala.util.intset.IntSet;
import com.ibm.wala.util.intset.MutableIntSet;

public class SolidityJSONLoader extends SolidityLoader {
	private final JSONObject originalTree;
	JSONToCAst solidityCode = new JSONToCAst(this);
	
	public SolidityJSONLoader(IClassHierarchy cha, IClassLoader parent, JSONObject originalTree) {
		super(cha, parent);
		this.originalTree = originalTree;
	}

	
	@Override
	protected TranslatorToCAst getTranslatorToCAst(CAst ast, ModuleEntry M, List<Module> modules) throws IOException {
		return solidityCode.new SolidityJSONTranslator(getJson(M));
	}

	private final Map<ModuleEntry,JSONObject> cache = HashMapFactory.make();
	
	private JSONObject getJson(ModuleEntry M) {
		if (! cache.containsKey(M)) {
			if (M instanceof SourceJSONModule) {
				cache.put(M,((SourceJSONModule)M).getJSON());
			} else {
				JSONTokener toks = new JSONTokener(M.getInputStream());
				cache.put(M, (JSONObject) toks.nextValue());
			}
		}

		return cache.get(M);
	}
	
	private MutableIntSet getDirectImports(JSONObject o)  {
		ImportVisitor v = new ImportVisitor();
		v.visit(o, null);
		return v.imports;
	}
	
	private final Map<Integer,JSONObject> sources = HashMapFactory.make();
	
	public JSONObject getSource(int id) {
		return sources.get(id);
	}
	
	public JSONObject getSources() {
		return originalTree;
	}
	
	@Override
	public void init(List<Module> modules) {
		Graph<Module> order = SlowSparseNumberedGraph.make();
		for(Module m : modules) {
			order.addNode(m);
		}
		
		for(Module s : modules) {
			JSONObject so = getJson((ModuleEntry) s);
			IntSet si = getDirectImports(so);
			for(Module t : modules) {
				if (s != t) {
					JSONObject to = getJson((ModuleEntry) t);
					if (si.contains(to.getInt("id"))) {
						order.addEdge(t, s);
					}
				}
			}
		}
		
		for(Module m : modules) {
			JSONObject su = getJson((ModuleEntry) m);
			sources.put(su.getInt("id"), su);
		}
		
		super.init(Streams.stream(Topological.makeTopologicalIter(order).iterator()).toList());
	}

	
}
