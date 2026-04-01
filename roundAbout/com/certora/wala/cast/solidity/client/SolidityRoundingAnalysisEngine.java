package com.certora.wala.cast.solidity.client;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;

import org.json.JSONArray;
import org.json.JSONObject;

import com.certora.wala.analysis.rounding.RoundingAnalysis;
import com.certora.wala.analysis.rounding.RoundingAnalysis.RoundingInference.Result;
import com.certora.wala.cast.solidity.util.JSONOutput;
import com.ibm.wala.cast.ipa.callgraph.CAstCallGraphUtil;
import com.ibm.wala.cast.loader.AstMethod;
import com.ibm.wala.ipa.callgraph.CGNode;
import com.ibm.wala.ipa.callgraph.CallGraph;
import com.ibm.wala.ipa.callgraph.propagation.PropagationCallGraphBuilder;
import com.ibm.wala.ipa.callgraph.propagation.SSAContextInterpreter;
import com.ibm.wala.util.CancelException;

public abstract class SolidityRoundingAnalysisEngine extends SolidityAnalysisEngine<JSONObject> {

	public SolidityRoundingAnalysisEngine(File confFile) throws FileNotFoundException {
		super(confFile);
	}

	@Override
	public JSONObject performAnalysis(PropagationCallGraphBuilder builder) throws CancelException {
		JSONArray graphs = new JSONArray();
		CallGraph cg = builder.getCallGraph();

		System.err.println(cg.getClassHierarchy());
		CAstCallGraphUtil.AVOID_DUMP.set(false);
		CAstCallGraphUtil.dumpCG((SSAContextInterpreter) builder.getContextInterpreter(), builder.getPointerAnalysis(), cg);

		RoundingAnalysis ra = new RoundingAnalysis(cg);
		for(CGNode n : cg) {
			if (n.getMethod() instanceof AstMethod) {
				Result G = ra.analyzeForNode(cg, n);

				graphs.put(JSONOutput.outputAsJSON(builder.getPointerAnalysis(), n, G));
			}
		}
		
		JSONObject G = new JSONObject();
		G.put("graphs", graphs);
		return G;
	}
	
	public JSONObject analyze() throws IOException, IllegalArgumentException, CancelException {
		buildAnalysisScope();
		buildClassHierarchy();
		PropagationCallGraphBuilder builder = defaultCallGraphBuilder();
		builder.makeCallGraph(builder.getOptions(), null);
		return performAnalysis(builder);
	}

}
