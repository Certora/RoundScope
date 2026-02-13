package com.certora.wala.analysis.rounding;

import java.util.Collections;
import java.util.Iterator;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

import com.certora.wala.analysis.defuse.DefUseGraph;
import com.ibm.wala.dataflow.ssa.SSAInference;
import com.ibm.wala.fixpoint.AbstractOperator;
import com.ibm.wala.fixpoint.AbstractVariable;
import com.ibm.wala.fixpoint.IVariable;
import com.ibm.wala.fixpoint.UnaryOperator;
import com.ibm.wala.ipa.callgraph.CGNode;
import com.ibm.wala.ipa.callgraph.CallGraph;
import com.ibm.wala.shrike.shrikeBT.IBinaryOpInstruction;
import com.ibm.wala.shrike.shrikeBT.IUnaryOpInstruction;
import com.ibm.wala.ssa.DefUse;
import com.ibm.wala.ssa.IR;
import com.ibm.wala.ssa.SSAAbstractInvokeInstruction;
import com.ibm.wala.ssa.SSABinaryOpInstruction;
import com.ibm.wala.ssa.SSACheckCastInstruction;
import com.ibm.wala.ssa.SSAInstruction;
import com.ibm.wala.ssa.SSAPhiInstruction;
import com.ibm.wala.ssa.SSAPiInstruction;
import com.ibm.wala.ssa.SSAReturnInstruction;
import com.ibm.wala.ssa.SSAUnaryOpInstruction;
import com.ibm.wala.util.CancelException;
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
	private final IR ir;
	private final DefUseGraph dug;

	public RoundingEstimator(CGNode n, IR ir) {
		this.n = n;
		this.ir = ir;
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
				if (((SSABinaryOpInstruction) inst).getOperator() == IBinaryOpInstruction.Operator.DIV) {
					result.add((SSABinaryOpInstruction) inst);
				}
			}
		});
		return result;
	}

	private Set<SSAInstruction> getRelevant(SSAInstruction inst, NumberedGraph<Integer> g) {
		if (inst == null) {
			return Collections.emptySet();
		} else if (inst.hasDef()) {
			int v = inst.getDef();
			return DFS.getReachableNodes(g, Collections.singleton(v)).stream().map(i -> dug.du().getDef(i))
					.filter(instr -> instr != null).collect(Collectors.toSet());
		} else {
			return Collections.emptySet();
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

	/*
	private Set<SSAInstruction> getQuotientRelated(SSABinaryOpInstruction div) {
		return getDerived(div);
	}
    */
	
	private static MutableIntSet getRelatedValues(int startValue, Set<SSAInstruction> related, boolean forward) {
		return IntSetUtil.make(IntStream
				.concat(related.stream()
						.map(inst -> (forward ? IntStream.of(inst.getDef()).filter(i -> i > 0)
								: IntStream.range(0, inst.getNumberOfUses()).map(i -> inst.getUse(i))))
						.reduce((a, b) -> IntStream.concat(a, b)).orElse(IntStream.empty()), IntStream.of(startValue))
				.distinct().toArray());
	}

	public static enum Direction {
		Either {
			@Override
			Direction meet(Direction d) {
				return Either;
			}

			@Override
			Direction flip() {
				return Either;
			}
		},
		Neither {
			@Override
			Direction meet(Direction d) {
				switch (d) {
				case Neither:
					return Neither;
				case Up:
					return Up;
				case Down:
					return Down;
				case Either:
					return Either;
				default:
					return Either;
				}
			}

			@Override
			Direction flip() {
				return Neither;
			}
		},
		Up {
			@Override
			Direction meet(Direction d) {
				switch (d) {
				case Neither:
					return Up;
				case Up:
					return Up;
				case Down:
					return Either;
				case Either:
					return Either;
				default:
					return Either;
				}
			}

			@Override
			Direction flip() {
				return Down;
			}
		},
		Down {
			@Override
			Direction meet(Direction d) {
				switch (d) {
				case Neither:
					return Down;
				case Up:
					return Either;
				case Down:
					return Down;
				case Either:
					return Either;
				default:
					return Either;
				}
			}

			@Override
			Direction flip() {
				return Up;
			}
		};

		abstract Direction meet(Direction d);

		abstract Direction flip();
	};

	public class RoundingInference extends SSAInference<RoundingInference.RoundingVariable> {
		private class RoundingVariable extends AbstractVariable<RoundingVariable> {
			int vn;
			Direction state;
			SSAInstruction wrt;
			public RoundingVariable(int vn, Direction state, SSAInstruction wrt) {
				this.vn = vn;
				this.wrt = wrt;
				this.state = state;
			}

			public RoundingVariable(int vn) {
				this.vn = vn;
				
			}
			
			@Override
			public void copyState(RoundingVariable v) {
				state = v.state;
				wrt = v.wrt;
			}

			@Override
			public String toString() {
				return "<" + state + "(" + wrt + ")>";
			}
			
		}

		private final AbstractOperator<RoundingVariable> phiOperator = new AbstractOperator<RoundingVariable>() {
			@Override
			public byte evaluate(RoundingVariable lhs, RoundingVariable[] rhs) {
				boolean up = rhs[0].state==Direction.Up;
				SSAInstruction upHack = rhs[0].wrt;
				if (upHack != null) check: {
					for (int i = 1; i < rhs.length; i++) {
						if (rhs[i].wrt != upHack) {
							break check;
						}
						up |= (rhs[i].state == Direction.Up);
					}
					
					if (up) {
						if (lhs.state != Direction.Up) {
							lhs.state = Direction.Up;
							lhs.wrt = rhs[0].wrt;
							return CHANGED;
						}
					}
				}
				
				SSAInstruction wrt = rhs[0].wrt;
				Direction d = rhs[0].state;
				if (d == null) {
					d = Direction.Neither;
				}
				for (int i = 1; i < rhs.length; i++) {
					d = d.meet(rhs[i].state == null? Direction.Neither: rhs[i].state);
					if (rhs[i].wrt != wrt) {
						wrt = null;
					}
				}

				if (d != lhs.state || wrt != lhs.wrt) {
					lhs.state = d;
					lhs.wrt = wrt;
					return CHANGED;
				} else {
					return NOT_CHANGED;
				}
			}

			@Override
			public int hashCode() {
				return 34659878;
			}

			@Override
			public boolean equals(Object o) {
				return o == this;
			}

			@Override
			public String toString() {
				return "rounding phi operator";
			}
		};

		private final AbstractOperator<RoundingVariable> piOperator = new AbstractOperator<RoundingVariable>() {
			@Override
			public byte evaluate(RoundingVariable lhs, RoundingVariable[] rhs) {
				Direction d = rhs[0].state;

				if (d != lhs.state || lhs.wrt != rhs[0].wrt) {
					lhs.state = d;
					lhs.wrt = rhs[0].wrt;
					return CHANGED;
				} else {
					return NOT_CHANGED;
				}
			}

			@Override
			public int hashCode() {
				return 763469878;
			}

			@Override
			public boolean equals(Object o) {
				return o == this;
			}

			@Override
			public String toString() {
				return "rounding phi operator";
			}
		};

		private final AbstractOperator<RoundingVariable> flipOperator = new AbstractOperator<RoundingVariable>() {
			@Override
			public byte evaluate(RoundingVariable lhs, RoundingVariable[] rhs) {
				if (rhs[0] != null && rhs[0].state != null) {
					Direction d = rhs[0].state.flip();

					if (d != lhs.state || lhs.wrt != rhs[0].wrt) {
						lhs.state = d;
						lhs.wrt = rhs[0].wrt;
						return CHANGED;
					} 
				}
				return NOT_CHANGED;
			}

			@Override
			public int hashCode() {
				return 234235346;
			}

			@Override
			public boolean equals(Object o) {
				return o == this;
			}

			@Override
			public String toString() {
				return "rounding flip operator";
			}
		};

		private AbstractOperator<RoundingVariable> assignOperator = new AbstractOperator<RoundingVariable>() {
			@Override
			public byte evaluate(RoundingVariable lhs, RoundingVariable[] rhs) {
				if (lhs.state != rhs[0].state) {
					lhs.state = rhs[0].state;
					return CHANGED;
				} else {
					return NOT_CHANGED;
				}
			}

			@Override
			public int hashCode() {
				return 87798708;
			}

			@Override
			public boolean equals(Object o) {
				return o == this;
			}

			@Override
			public String toString() {
				return "rounding assign operator";
			}

		};

		private class BinaryOperator extends AbstractOperator<RoundingVariable> {
			private final boolean flipRight;
			private final Direction init;
			protected final SSAInstruction inst;
			
			public BinaryOperator(boolean flipRight, Direction init, SSAInstruction inst) {
				this.flipRight = flipRight;
				this.init = init;
				this.inst = inst;
			}

			public BinaryOperator(boolean flipRight, Direction init) {
				this(flipRight, init, null);
			}

			@Override
			public byte evaluate(RoundingVariable lhs, RoundingVariable[] rhs) {
				if (rhs[0].state != null && rhs[1].state != null) {
					Direction d = rhs[0].state;
					d = d==null? d: d.meet(flipRight? rhs[1].state.flip(): rhs[1].state);
					d = d==null? init: init.meet(d);
				
					if (d != lhs.state || (rhs[0].wrt == rhs[1].wrt && rhs[0].wrt != lhs.wrt)) {
						lhs.state = d;
						lhs.wrt = init!=Direction.Neither? inst:rhs[0].wrt == rhs[1].wrt? rhs[0].wrt: null;
						return CHANGED;
					} 
				}
				
				return NOT_CHANGED;	
			}

			@Override
			public int hashCode() {
				return 6745836 * init.hashCode() * (flipRight? 1: -1);
			}

			@Override
			public boolean equals(Object o) {
				return o.getClass() == this.getClass() && 
					init==((BinaryOperator)o).init &&
					flipRight==((BinaryOperator)o).flipRight;
			}

			@Override
			public String toString() {
				return "rounding bin op " + init + " " + flipRight;
			}
			
		}
		
		private class RoundUpDetestionOperator extends BinaryOperator {
			RoundUpDetestionOperator(SSAInstruction inst) {
				super(false, Direction.Neither, inst);
			}
			
			boolean isDivDown(RoundingVariable v) {
				return v != null && v.state == Direction.Down && v.wrt != null && v.wrt.getDef()==v.vn;
			}
			
			@Override
			public byte evaluate(RoundingVariable lhs, RoundingVariable[] rhs) {
				if (isDivDown(rhs[0]) && rhs[1].state == Direction.Neither) {
					if (lhs.state != Direction.Up) {
						lhs.state = Direction.Up;
						lhs.wrt = rhs[0].wrt;
						return CHANGED;
					}
				} else if (isDivDown(rhs[1]) && rhs[0].state == Direction.Neither) {
					if (lhs.state != Direction.Up) {
						lhs.state = Direction.Up;
						lhs.wrt = rhs[1].wrt;
						return CHANGED;
					}
				} else {
					return super.evaluate(lhs, rhs);
				}
				
				return NOT_CHANGED;
			}
		}
		
		class ConstantOperator extends AbstractOperator<RoundingVariable> {
			private final Direction d;
			
			public ConstantOperator(Direction d) {
				this.d = d;
			}

			@Override
			public byte evaluate(RoundingVariable lhs, RoundingVariable[] rhs) {
				if (lhs.state != d) {
					lhs.state = d;
					return CHANGED;
				} else {
					return NOT_CHANGED;
				}
			}

			@Override
			public int hashCode() {
				return d.hashCode()*668976;
			}

			@Override
			public boolean equals(Object o) {
				return o != null && 
					getClass() == o.getClass() &&
					d.equals(((ConstantOperator)o).d);
			}

			@Override
			public String toString() {
				return "constant " + d;
			}
		};
		
		private Set<RoundingVariable> result = HashSetFactory.make();

		public RoundingInference(CallGraph CG, Map<CGNode, Direction> directionalCalls, CGNode n) throws CancelException {
			IR ir = n.getIR();
			DefUse du = n.getDU();
			
			class RoundingOperatorFactory extends SSAInstruction.Visitor implements OperatorFactory<RoundingVariable> {
				private AbstractOperator<RoundingVariable> result;

				@Override
				public AbstractOperator<RoundingVariable> get(SSAInstruction instruction) {
					result = null;
					instruction.visit(this);
					return result;
				}

				@Override
				public void visitBinaryOp(SSABinaryOpInstruction instruction) {
					IBinaryOpInstruction.IOperator op = instruction.getOperator();
					if (op == IBinaryOpInstruction.Operator.ADD) {
						result = new RoundUpDetestionOperator(instruction);
						
					} else if (op == IBinaryOpInstruction.Operator.MUL) {
						result = new BinaryOperator(false, Direction.Neither);
						
					} else if (op == IBinaryOpInstruction.Operator.DIV) {
						Set<SSAInstruction> divisor = getDivisorRelated(instruction);
						Set<SSAInstruction> dividend = getDividendRelated(instruction);

						MutableIntSet bothValues = getRelatedValues(instruction.getUse(1), divisor, false);
						bothValues.intersectWith(getRelatedValues(instruction.getUse(0), dividend, false));
						Direction d = bothValues.isEmpty()? Direction.Down: Direction.Up;

						result = new BinaryOperator(true, d, instruction);

					} else if (op == IBinaryOpInstruction.Operator.SUB) {
						
						result = new BinaryOperator(true, Direction.Neither);
					
					} else {
						result = new ConstantOperator(Direction.Neither);
					}
				}

				@Override
				public void visitUnaryOp(SSAUnaryOpInstruction instruction) {
					IUnaryOpInstruction.IOperator op = instruction.getOpcode();
					if (op == IUnaryOpInstruction.Operator.NEG) {
						result = flipOperator;
					} else {
						result = assignOperator;
					}
				}

				@Override
				public void visitCheckCast(SSACheckCastInstruction instruction) {
					result = piOperator;
				}

				@Override
				public void visitPhi(SSAPhiInstruction instruction) {
					result = phiOperator;
				}

				@Override
				public void visitPi(SSAPiInstruction instruction) {
					result = piOperator;
				}
			}

			class RoundingVariableFactory implements VariableFactory<RoundingVariable> {
				private boolean hasReturn(int vn) {
					Iterator<SSAInstruction> is = du.getUses(vn);
					while(is.hasNext()) {
						if (is.next() instanceof SSAReturnInstruction) {
							return true;
						}
 					}
					return false;
				}
				
				@Override
				public IVariable<RoundingVariable> makeVariable(int valueNumber) {
					RoundingVariable v;
					if (ir.getSymbolTable().isConstant(valueNumber) || valueNumber <= ir.getSymbolTable().getNumberOfParameters()) {
						v = new RoundingVariable(valueNumber, Direction.Neither, null);

					} else if (du.getDef(valueNumber) instanceof SSAAbstractInvokeInstruction && ((SSAAbstractInvokeInstruction)du.getDef(valueNumber)).hasDef()) {
						Direction d = Direction.Neither;
						for (CGNode cgn : CG.getPossibleTargets(n,
								((SSAAbstractInvokeInstruction) du.getDef(valueNumber)).getCallSite())) {
							if (directionalCalls.containsKey(cgn)) {
								d = d.meet(directionalCalls.get(cgn));
							}
						}
						v = new RoundingVariable(valueNumber, d, du.getDef(valueNumber));

					} else {
						v = new RoundingVariable(valueNumber);
					}
					
					if (hasReturn(valueNumber)) {
						result.add(v);
					}
					
					return v;
				}

			}

			init(ir, new RoundingVariableFactory(), new RoundingOperatorFactory());
			solve(null);
		}

		@Override
		protected RoundingVariable[] makeStmtRHS(int size) {
			return new RoundingVariable[size];
		}

		@Override
		protected void initializeVariables() {
			// TODO Auto-generated method stub

		}

		@Override
		protected void initializeWorkList() {
			addAllStatementsToWorkList();
		}

		@Override
		public int hashCode() {
			return ir.getMethod().hashCode();
		}

		@Override
		public boolean equals(Object o) {
			return o == this;
		}

		public Direction getResult() {
			return result.stream().filter(x -> x.state != null).map(x -> x.state).reduce(Direction::meet).orElse(Direction.Neither);
		}

		@Override
		public String toString() {
			return super.toString() + "returning " + result;
		}
	}

	private void process(SSAInstruction inst, Direction dir, MutableIntSet upValues, MutableIntSet downValues) {
		Set<SSAInstruction> flow = getDerived(inst);
		if (dir == Direction.Up) {
			IntSet flowValues = getRelatedValues(inst.getDef(), flow, true);
			upValues.addAll(flowValues);
		} else {
			MutableIntSet flowValues = getRelatedValues(inst.getDef(), flow, true);
			Set<SSAInstruction> flowAdds = flow.stream()
					.filter(instr -> instr instanceof SSABinaryOpInstruction
							&& ((SSABinaryOpInstruction) instr).getOperator() == IBinaryOpInstruction.Operator.ADD)
					.collect(Collectors.toSet());
			IntSet ups = flowAdds.stream()
					.map(instr -> (IntSet) getRelatedValues(instr.getDef(), getDerived(instr), true))
					.reduce((a, b) -> a.union(b)).orElse(EmptyIntSet.instance);
			ups.foreach(i -> flowValues.remove(i));
			downValues.addAll(flowValues);
			upValues.addAll(ups);
		}
	}

	public Direction analyze(CallGraph CG, Map<CGNode, Direction> directionalCalls) {
		MutableIntSet upValues = IntSetUtil.make();
		MutableIntSet downValues = IntSetUtil.make();

		for (SSABinaryOpInstruction div : getDivisions()) {
			Set<SSAInstruction> divisor = getDivisorRelated(div);
			Set<SSAInstruction> dividend = getDividendRelated(div);

			MutableIntSet bothValues = getRelatedValues(div.getUse(1), divisor, false);
			bothValues.intersectWith(getRelatedValues(div.getUse(0), dividend, false));

			if (!bothValues.isEmpty()) {
				process(div, Direction.Up, upValues, downValues);
			} else {
				process(div, Direction.Down, upValues, downValues);
			}
		}

		if (n != null) {
			for (SSAInstruction inst : dug.ir().getInstructions()) {
				Direction d = Direction.Neither;
				if (inst instanceof SSAAbstractInvokeInstruction) {
					for (CGNode cgn : CG.getPossibleTargets(n, ((SSAAbstractInvokeInstruction) inst).getCallSite())) {
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
