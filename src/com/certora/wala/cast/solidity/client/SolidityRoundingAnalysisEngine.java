package com.certora.wala.cast.solidity.client;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;

import org.json.JSONArray;

import com.certora.wala.analysis.rounding.RoundingAnalysis;
import com.certora.wala.analysis.rounding.RoundingAnalysis.RoundingInference.Result;
import com.certora.wala.cast.solidity.util.JSONOutput;
import com.ibm.wala.ipa.callgraph.CGNode;
import com.ibm.wala.ipa.callgraph.CallGraph;
import com.ibm.wala.ipa.callgraph.propagation.PropagationCallGraphBuilder;
import com.ibm.wala.util.CancelException;

public class SolidityRoundingAnalysisEngine extends SolidityAnalysisEngine<JSONArray> {

	public SolidityRoundingAnalysisEngine(File confFile) throws FileNotFoundException {
		super(confFile);
	}

	@Override
	public JSONArray performAnalysis(PropagationCallGraphBuilder builder) throws CancelException {
		JSONArray graphs = new JSONArray();
		CallGraph cg = builder.getCallGraph();
		for(CGNode n : cg.getEntrypointNodes()) {
			
			Result G = RoundingAnalysis.analyzeForNode(cg, n);

		    graphs.put(JSONOutput.outputAsJSON(builder.getPointerAnalysis(), n, G));

		    String res = G.toString();
		    if (res.contains("--> Up") || res.contains("--> Down") || res.contains("--> Either")) {
				System.out.println("looking at " + n + "  --> " + G.getReturnRounding());
		    	System.out.println(res);
		    }
		}
		
		return graphs;
	}
	
	public JSONArray analyze() throws IOException, IllegalArgumentException, CancelException {
		buildAnalysisScope();
		buildClassHierarchy();
		PropagationCallGraphBuilder builder = defaultCallGraphBuilder();
		builder.makeCallGraph(builder.getOptions(), null);
		return performAnalysis(builder);
	}

}
