package com.certora.wala.analysis.rounding;

import java.util.Collections;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

import com.certora.wala.analysis.defuse.DefUseGraph;
import com.ibm.wala.classLoader.IMethod;
import com.ibm.wala.ipa.callgraph.CGNode;
import com.ibm.wala.ipa.callgraph.CallGraph;
import com.ibm.wala.shrike.shrikeBT.IBinaryOpInstruction;
import com.ibm.wala.ssa.IR;
import com.ibm.wala.ssa.SSAAbstractInvokeInstruction;
import com.ibm.wala.ssa.SSABinaryOpInstruction;
import com.ibm.wala.ssa.SSAInstruction;
import com.ibm.wala.ssa.SSAReturnInstruction;
import com.ibm.wala.util.collections.HashSetFactory;
import com.ibm.wala.util.graph.NumberedGraph;
import com.ibm.wala.util.graph.impl.GraphInverter;
import com.ibm.wala.util.graph.traverse.DFS;
import com.ibm.wala.util.intset.EmptyIntSet;
import com.ibm.wala.util.intset.IntSet;
import com.ibm.wala.util.intset.IntSetUtil;
import com.ibm.wala.util.intset.MutableIntSet;

public class RoundingEstimator {
	private final CGNode n;
	private final DefUseGraph dug;
	
	public RoundingEstimator(CGNode n, IR ir) {
		this.n = n;
		this.dug = new DefUseGraph(ir);
	}

	public RoundingEstimator(IR ir) {
		this(null, ir);
	}

	public RoundingEstimator(CGNode n) {
		this(n, n.getIR());
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
	
	public static enum Direction { Either {
			@Override
			Direction meet(Direction d) {
				return Either;
			}
		},	Neither {
			@Override
			Direction meet(Direction d) {
				switch (d) {
				case Neither: return Neither;
				case Up: return Up;
				case Down: return Down;
				case Either: return Either;
				default: return Either; 
				}
			}
		}, Up {
			@Override
			Direction meet(Direction d) {
				switch (d) {
				case Neither: return Up;
				case Up: return Up;
				case Down: return Either;
				case Either: return Either;
				default: return Either; 
				}
			}
		}, Down {
			@Override
			Direction meet(Direction d) {
				switch (d) {
				case Neither: return Down;
				case Up: return Either;
				case Down: return Down;
				case Either: return Either;
				default: return Either; 
				}
			}
		};		
		
		abstract Direction meet(Direction d);
	};
	
	private void process(SSAInstruction inst, Direction dir, MutableIntSet upValues, MutableIntSet downValues) {
		Set<SSAInstruction> flow = getDerived(inst);
		if (dir == Direction.Up) {
			IntSet flowValues = getRelatedValues(inst.getDef(), flow, true);
			upValues.addAll(flowValues);
		} else {
			MutableIntSet flowValues = getRelatedValues(inst.getDef(), flow, true);
			Set<SSAInstruction> flowAdds = flow.stream().filter(instr -> instr instanceof SSABinaryOpInstruction && ((SSABinaryOpInstruction)instr).getOperator() == IBinaryOpInstruction.Operator.ADD).collect(Collectors.toSet());
			IntSet ups = flowAdds.stream().map(instr -> (IntSet)getRelatedValues(instr.getDef(), getDerived(instr), true)).reduce((a, b) -> a.union(b)).orElse(EmptyIntSet.instance);
			ups.foreach(i -> flowValues.remove(i));
			downValues.addAll(flowValues);
			upValues.addAll(ups);
		}
	}
	
	public Direction analyze(CallGraph CG, Map<CGNode, Direction> directionalCalls) {
		MutableIntSet upValues = IntSetUtil.make();
		MutableIntSet downValues = IntSetUtil.make();
		
		for(SSABinaryOpInstruction div : getDivisions()) {
			Set<SSAInstruction> divisor = getDivisorRelated(div);
			Set<SSAInstruction> dividend = getDividendRelated(div);

			MutableIntSet bothValues = getRelatedValues(div.getUse(1), divisor, false);
			bothValues.intersectWith(getRelatedValues(div.getUse(0), dividend, false));
			
			if (! bothValues.isEmpty()) {
				process(div, Direction.Up, upValues, downValues);
			} else {
				process(div, Direction.Down, upValues, downValues);				
			}
		}
		
		if (n != null) {
			for (SSAInstruction inst : dug.ir().getInstructions()) {
				Direction d = Direction.Neither;
				if (inst instanceof SSAAbstractInvokeInstruction) {
					for(CGNode cgn : CG.getPossibleTargets(n, ((SSAAbstractInvokeInstruction)inst).getCallSite())) {
						if (directionalCalls.containsKey(cgn)) {
							d = d.meet(directionalCalls.get(cgn));
						}
					}
				}
				if (d != Direction.Neither) {
					process(inst, d, upValues, downValues);
				}
			}
		}
		
		Direction d = Direction.Neither;
		for (SSAInstruction inst : dug.ir().getInstructions()) {
			if (inst instanceof SSAReturnInstruction) {
				int rv = inst.getUse(0);
				if (upValues.contains(rv)) {
					d = d.meet(Direction.Up);
				}
				if (downValues.contains(rv)) {
					d = d.meet(Direction.Down);
				}
			}
		}

		return d;
	}
}

