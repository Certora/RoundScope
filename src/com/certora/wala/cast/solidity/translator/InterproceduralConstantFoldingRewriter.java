package com.certora.wala.cast.solidity.translator;

import java.util.Arrays;
import java.util.Map;

import com.ibm.wala.cast.ir.translator.ConstantFoldingRewriter;
import com.ibm.wala.cast.tree.CAst;
import com.ibm.wala.cast.tree.CAstControlFlowMap;
import com.ibm.wala.cast.tree.CAstEntity;
import com.ibm.wala.cast.tree.CAstNode;
import com.ibm.wala.ipa.callgraph.Context;
import com.ibm.wala.ipa.callgraph.ContextItem;
import com.ibm.wala.ipa.callgraph.ContextKey;
import com.ibm.wala.ipa.callgraph.propagation.ConstantKey;
import com.ibm.wala.ipa.callgraph.propagation.FilteredPointerKey.SingleInstanceFilter;
import com.ibm.wala.util.collections.Pair;

public abstract class InterproceduralConstantFoldingRewriter extends ConstantFoldingRewriter {

	protected final Context context;
	protected final CAstEntity fun;

	@Override
	protected CAstNode copyNodes(CAstNode root, CAstControlFlowMap cfg, NonCopyingContext context,
			Map<Pair<CAstNode, NoKey>, CAstNode> nodeMap) {
		int idx;
		if (root.getKind() == CAstNode.VAR && (idx=Arrays.asList(fun.getArgumentNames()).indexOf(root.getChild(0).getValue())) >= 0) {
			ContextItem type = this.context.get(ContextKey.PARAMETERS[idx]);
			if (type instanceof SingleInstanceFilter && ((SingleInstanceFilter)type).getInstance() instanceof ConstantKey) {
				CAstNode result = Ast.makeConstant(((ConstantKey<?>)((SingleInstanceFilter)type).getInstance()).getValue());
			    nodeMap.put(Pair.make(root, context.key()), result);
			    return result;
			}
		}
		
		return super.copyNodes(root, cfg, context, nodeMap);
	}

	public InterproceduralConstantFoldingRewriter(CAstEntity fun, Context context, CAst Ast) {
		super(Ast);
		this.fun = fun;
		this.context = context;
	}

}
