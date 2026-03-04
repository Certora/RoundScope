package com.certora.wala.cast.solidity.util;

import java.util.Set;

import org.json.JSONObject;

import com.certora.wala.analysis.rounding.RoundingAnalysis.RoundingInference.Result;
import com.ibm.wala.cast.tree.CAstSourcePositionMap.Position;
import com.ibm.wala.classLoader.IClass;
import com.ibm.wala.ipa.callgraph.CGNode;
import com.ibm.wala.util.graph.Graph;
import com.ibm.wala.util.graph.JGF;
import com.ibm.wala.util.graph.JGF.EntityTypes;
import com.ibm.wala.util.graph.labeled.NumberedLabeledGraph;

public class JSONOutput {

	public static String toLocalPos(Position p) {
		return "[" + p.getFirstLine() + "," + p.getFirstCol() + "-" + p.getLastLine() + "," + p.getLastCol()
				+ "]";
	}

	public static JSONObject outputAsJSON(CGNode n, Set<IClass> types, Result G) {
		NumberedLabeledGraph<JSONObject,Position> outGraph = G.toGraph();
		JSONObject out = JGF.toJGF(outGraph, new EntityTypes<JSONObject>() {
	
			@Override
			public JSONObject obj(JSONObject entity) {
				return entity;
			}
	
			@Override
			public String label(Graph<JSONObject> entity) {
				return "graph of " + n.getMethod().getReference() + " (" + types + ")";
			}
	
			@Override
			public String label(JSONObject from, JSONObject to) {
				Set<? extends Position> ps = outGraph.getEdgeLabels(from, to);
				return ps.stream().map(p -> p.getURL().getFile() + ":" +  toLocalPos(p)).reduce((a, b) -> a + b).orElse("");
			}
		});
		return out;
	}

}
