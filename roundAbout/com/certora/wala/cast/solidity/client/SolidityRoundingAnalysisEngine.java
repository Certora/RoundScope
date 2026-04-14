package com.certora.wala.cast.solidity.client;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.Set;

import org.json.JSONArray;
import org.json.JSONObject;

import com.certora.wala.analysis.rounding.RoundingAnalysis;
import com.certora.wala.analysis.rounding.RoundingAnalysis.RoundingInference.Result;
import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.certora.wala.cast.solidity.util.JSONOutput;
import com.ibm.wala.cast.ipa.callgraph.CAstCallGraphUtil;
import com.ibm.wala.cast.loader.AstMethod;
import com.ibm.wala.classLoader.IMethod;
import com.ibm.wala.classLoader.NewSiteReference;
import com.ibm.wala.classLoader.ProgramCounter;
import com.ibm.wala.ipa.callgraph.AnalysisOptions;
import com.ibm.wala.ipa.callgraph.CGNode;
import com.ibm.wala.ipa.callgraph.CallGraph;
import com.ibm.wala.ipa.callgraph.IAnalysisCacheView;
import com.ibm.wala.ipa.callgraph.propagation.InstanceKey;
import com.ibm.wala.ipa.callgraph.propagation.InstanceKeyFactory;
import com.ibm.wala.ipa.callgraph.propagation.PropagationCallGraphBuilder;
import com.ibm.wala.ipa.callgraph.propagation.SSAContextInterpreter;
import com.ibm.wala.ipa.cha.IClassHierarchy;
import com.ibm.wala.ssa.SSANewInstruction;
import com.ibm.wala.types.TypeReference;
import com.ibm.wala.util.CancelException;
import com.ibm.wala.util.collections.HashSetFactory;

public abstract class SolidityRoundingAnalysisEngine extends SolidityAnalysisEngine<JSONObject> {

	public SolidityRoundingAnalysisEngine(File confFile) throws FileNotFoundException {
		super(confFile);
	}

	@Override
	public JSONObject performAnalysis(PropagationCallGraphBuilder builder) throws CancelException {
		JSONArray graphs = new JSONArray();
		CallGraph cg = builder.getCallGraph();

		if (Boolean.getBoolean("verbose")) {
			System.err.println(cg.getClassHierarchy());
			CAstCallGraphUtil.AVOID_DUMP.set(false);
			CAstCallGraphUtil.dumpCG((SSAContextInterpreter) builder.getContextInterpreter(), builder.getPointerAnalysis(), cg);
		}
		
		Set<IMethod> done = HashSetFactory.make();
		RoundingAnalysis ra = new RoundingAnalysis(cg, builder.getPointerAnalysis());
		
		for(CGNode n : cg.getEntrypointNodes()) {
			if (n.getMethod() instanceof AstMethod) {
				done.add(n.getMethod());
				Result G = ra.analyzeForNode(cg, n);
				
				graphs.put(JSONOutput.outputAsJSON(builder.getPointerAnalysis(), n, G));
			}
		}
		
		for(CGNode n : cg) {
			if (n.getMethod() instanceof AstMethod && ! done.contains(n.getMethod())) {
				done.add(n.getMethod());
				Result G = ra.analyzeForNode(cg, n);
				
				graphs.put(JSONOutput.outputAsJSON(builder.getPointerAnalysis(), n, G));
			}
		}
		
		JSONObject G = new JSONObject();
		G.put("graphs", graphs);
		return G;
	}
	
	@Override
	protected PropagationCallGraphBuilder getCallGraphBuilder(IClassHierarchy cha, AnalysisOptions options,
			IAnalysisCacheView analysisCache) {
		PropagationCallGraphBuilder x = super.getCallGraphBuilder(cha, options, analysisCache);
		InstanceKeyFactory f = x.getInstanceKeys();
		x.setInstanceKeys(new InstanceKeyFactory() {

			@Override
			public InstanceKey getInstanceKeyForAllocation(CGNode node, NewSiteReference allocation) {
				if (node.getClassHierarchy().lookupClass(allocation.getDeclaredType()) != null && 
					node.getClassHierarchy().isAssignableFrom(node.getClassHierarchy().lookupClass(SolidityTypes.enm), node.getClassHierarchy().lookupClass(allocation.getDeclaredType()))) {
					SSANewInstruction inst = node.getIR().getNew(allocation);
					if (inst.getNumberOfUses() > 0) {
						Object o = node.getIR().getSymbolTable().getConstantValue(inst.getUse(0));
						return f.getInstanceKeyForConstant(inst.getConcreteType(), o);
					}
				} 
				
				return f.getInstanceKeyForAllocation(node, allocation);
			}

			@Override
			public InstanceKey getInstanceKeyForMultiNewArray(CGNode node, NewSiteReference allocation, int dim) {
				return f.getInstanceKeyForMultiNewArray(node, allocation, dim);
			}

			@Override
			public <T> InstanceKey getInstanceKeyForConstant(TypeReference type, T S) {
				return f.getInstanceKeyForConstant(type, S);
			}

			@Override
			public InstanceKey getInstanceKeyForPEI(CGNode node, ProgramCounter instr, TypeReference type) {
				return f.getInstanceKeyForPEI(node, instr, type);
			}

			@Override
			public InstanceKey getInstanceKeyForMetadataObject(Object obj, TypeReference objType) {
				return f.getInstanceKeyForMetadataObject(obj, objType);
			} 
			
		});
		return x;
	}
	
	public JSONObject analyze() throws IOException, IllegalArgumentException, CancelException {
		buildAnalysisScope();
		buildClassHierarchy();
		PropagationCallGraphBuilder builder = defaultCallGraphBuilder();
		builder.makeCallGraph(builder.getOptions(), null);
		return performAnalysis(builder);
	}

}
