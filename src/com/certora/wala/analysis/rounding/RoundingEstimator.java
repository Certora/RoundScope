package com.certora.wala.analysis.rounding;

import java.util.Collections;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

import com.certora.wala.analysis.gvn.DefUseGraph;
import com.ibm.wala.shrike.shrikeBT.IBinaryOpInstruction;
import com.ibm.wala.ssa.IR;
import com.ibm.wala.ssa.SSABinaryOpInstruction;
import com.ibm.wala.ssa.SSAInstruction;
import com.ibm.wala.util.collections.HashSetFactory;
import com.ibm.wala.util.graph.NumberedGraph;
import com.ibm.wala.util.graph.impl.GraphInverter;
import com.ibm.wala.util.graph.traverse.DFS;
import com.ibm.wala.util.intset.IntSetUtil;
import com.ibm.wala.util.intset.MutableIntSet;

public class RoundingEstimator {
	private final DefUseGraph dug;
	
	public RoundingEstimator(IR ir) {
		this.dug = new DefUseGraph(ir);
	}

	private Set<SSABinaryOpInstruction> getDivisions() {
		Set<SSABinaryOpInstruction> result = HashSetFactory.make();
		dug.ir().iterateAllInstructions().forEachRemaining(inst -> { 
			if (inst instanceof SSABinaryOpInstruction) {
				if (((SSABinaryOpInstruction)inst).getOperator() == IBinaryOpInstruction.Operator.DIV) {
					result.add((SSABinaryOpInstruction)inst);
				}
			}
		});
		return result;
	}
	
	private Set<SSAInstruction> getRelevant(SSAInstruction inst, NumberedGraph<Integer> g) {
		if (inst == null) {
			return Collections.emptySet();
		} else {
			int v = inst.getDef();
			return DFS.getReachableNodes(g, Collections.singleton(v)).stream().map(i -> dug.du().getDef(i)).filter(instr -> instr != null).collect(Collectors.toSet());
		}
	}

	private Set<SSAInstruction> getDerived(SSAInstruction inst) {
		return getRelevant(inst, dug);
	}

	private Set<SSAInstruction> getDeriving(SSAInstruction inst) {
		return getRelevant(inst, GraphInverter.invert(dug));
	}

	private Set<SSAInstruction> getDivisorRelated(SSABinaryOpInstruction div) {
		return getDeriving(dug.du().getDef(div.getUse(1)));
	}

	private Set<SSAInstruction> getDividendRelated(SSABinaryOpInstruction div) {
		return getDeriving(dug.du().getDef(div.getUse(0)));
	}

	private Set<SSAInstruction> getQuotientRelated(SSABinaryOpInstruction div) {
		return getDerived(div);
	}

	private static MutableIntSet getRelatedValues(int startValue, Set<SSAInstruction> related, boolean forward) {
		return IntSetUtil.make(
			IntStream.concat(
				related.stream().map(inst -> 
					(forward?
						IntStream.of(inst.getDef()).filter(i -> i > 0):
						IntStream.range(0, inst.getNumberOfUses()).map(i -> inst.getUse(i))))
				.reduce((a, b) -> IntStream.concat(a,  b))
				.orElse(IntStream.empty()),
			IntStream.of(startValue))
		.distinct().toArray());
	}
	
	public void analyze() {
		for(SSABinaryOpInstruction div : getDivisions()) {
			Set<SSAInstruction> divisor = getDivisorRelated(div);
			Set<SSAInstruction> dividend = getDividendRelated(div);

			MutableIntSet bothValues = getRelatedValues(div.getUse(1), divisor, false);
			bothValues.intersectWith(getRelatedValues(div.getUse(0), dividend, false));
			System.err.println(bothValues);
			
			Set<SSAInstruction> quotient = getQuotientRelated(div);
			Set<SSAInstruction> quotientAdds = quotient.stream().filter(inst -> inst instanceof SSABinaryOpInstruction && ((SSABinaryOpInstruction)inst).getOperator() == IBinaryOpInstruction.Operator.ADD).collect(Collectors.toSet());
			for(SSAInstruction qa : quotientAdds) {
				System.err.println(getRelatedValues(qa.getDef(), getDerived(qa), true));
			}
		}
	}
}

