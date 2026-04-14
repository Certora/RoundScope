package com.certora.wala.analysis.rounding;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

import org.json.JSONArray;
import org.json.JSONObject;

import com.certora.wala.analysis.defuse.DefUseGraph;
import com.certora.wala.analysis.rounding.RoundingAnalysis.RoundingInference.Result;
import com.certora.wala.cast.solidity.util.JSONOutput;
import com.google.common.collect.Sets;
import com.google.common.collect.Streams;
import com.ibm.wala.cast.ir.ssa.CAstBinaryOp;
import com.ibm.wala.cast.loader.AstMethod;
import com.ibm.wala.cast.loader.AstMethod.DebuggingInformation;
import com.ibm.wala.cast.tree.CAstSourcePositionMap.Position;
import com.ibm.wala.cast.util.SourceBuffer;
import com.ibm.wala.cfg.Util;
import com.ibm.wala.cfg.cdg.ControlDependenceGraph;
import com.ibm.wala.dataflow.ssa.SSAInference;
import com.ibm.wala.fixpoint.AbstractOperator;
import com.ibm.wala.fixpoint.AbstractVariable;
import com.ibm.wala.fixpoint.IVariable;
import com.ibm.wala.ipa.callgraph.CGNode;
import com.ibm.wala.ipa.callgraph.CallGraph;
import com.ibm.wala.ipa.callgraph.ContextItem;
import com.ibm.wala.ipa.callgraph.ContextKey;
import com.ibm.wala.ipa.callgraph.propagation.ConstantKey;
import com.ibm.wala.ipa.callgraph.propagation.FilteredPointerKey.SingleInstanceFilter;
import com.ibm.wala.ipa.callgraph.propagation.InstanceKey;
import com.ibm.wala.ipa.callgraph.propagation.PointerAnalysis;
import com.ibm.wala.ipa.callgraph.propagation.PointerKey;
import com.ibm.wala.shrike.shrikeBT.IBinaryOpInstruction;
import com.ibm.wala.shrike.shrikeBT.IShiftInstruction;
import com.ibm.wala.shrike.shrikeBT.IUnaryOpInstruction;
import com.ibm.wala.ssa.DefUse;
import com.ibm.wala.ssa.IR;
import com.ibm.wala.ssa.ISSABasicBlock;
import com.ibm.wala.ssa.SSAAbstractInvokeInstruction;
import com.ibm.wala.ssa.SSABinaryOpInstruction;
import com.ibm.wala.ssa.SSACFG;
import com.ibm.wala.ssa.SSACheckCastInstruction;
import com.ibm.wala.ssa.SSAConditionalBranchInstruction;
import com.ibm.wala.ssa.SSAInstruction;
import com.ibm.wala.ssa.SSAInvokeInstruction;
import com.ibm.wala.ssa.SSAPhiInstruction;
import com.ibm.wala.ssa.SSAPiInstruction;
import com.ibm.wala.ssa.SSAPutInstruction;
import com.ibm.wala.ssa.SSAReturnInstruction;
import com.ibm.wala.ssa.SSAUnaryOpInstruction;
import com.ibm.wala.types.FieldReference;
import com.ibm.wala.util.CancelException;
import com.ibm.wala.util.collections.HashMapFactory;
import com.ibm.wala.util.collections.HashSetFactory;
import com.ibm.wala.util.collections.Pair;
import com.ibm.wala.util.graph.NumberedGraph;
import com.ibm.wala.util.graph.dominators.Dominators;
import com.ibm.wala.util.graph.impl.GraphInverter;
import com.ibm.wala.util.graph.labeled.NumberedLabeledGraph;
import com.ibm.wala.util.graph.labeled.SlowSparseNumberedLabeledGraph;
import com.ibm.wala.util.graph.traverse.DFS;
import com.ibm.wala.util.intset.IntSetUtil;
import com.ibm.wala.util.intset.MutableIntSet;
import com.ibm.wala.util.intset.OrdinalSet;

public class RoundingAnalysis {
	private final boolean IMPLICIT_NEITHER = true;
	
	private final CallGraph CG;
	private final PointerAnalysis<InstanceKey> PA;
	private final Map<Pair<CGNode, List<Direction>>, RoundingInference.Result> rawResults = HashMapFactory.make();
	private final Map<Pair<CGNode, List<Direction>>, Map<FieldReference, Direction>> directionalCalls = HashMapFactory
			.make();


	public RoundingAnalysis(CallGraph CG, PointerAnalysis<InstanceKey> PA) {
		this.CG = CG;
		this.PA = PA;
	}

	public class RoundingInference extends SSAInference<RoundingInference.RoundingVariable> {
		private final Set<RoundingInference.RoundingVariable> result = HashSetFactory.make();

		private class RoundingVariable extends AbstractVariable<RoundingVariable> {
			int vn;
			Direction state;
			SSAInstruction wrt;

			public RoundingVariable(int vn, Direction state, SSAInstruction wrt) {
				this.vn = vn;
				this.wrt = wrt;
				this.state = state;
			}

			@Override
			public void copyState(RoundingVariable v) {
				state = v.state;
				wrt = v.wrt;
			}

			@Override
			public String toString() {
				return "<" + vn + ":" + state + "(" + wrt + ")>";
			}
		}

		private final AbstractOperator<RoundingVariable> phiOperator = new AbstractOperator<RoundingVariable>() {
			@Override
			public byte evaluate(RoundingVariable lhs, RoundingVariable[] rhs) {
				boolean up = rhs[0].state == Direction.Up;
				SSAInstruction upHack = rhs[0].wrt;
				if (upHack != null) {
					check: {
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
				}

				SSAInstruction wrt = rhs[0].wrt;
				Direction d = rhs[0].state;
				if (d == null) {
					d = Direction.Neither;
				}
				for (int i = 1; i < rhs.length; i++) {
					d = d.meet(rhs[i].state == null ? Direction.Neither : rhs[i].state);
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
				if (lhs.state != rhs[0].state || lhs.wrt != rhs[0].wrt) {
					lhs.state = rhs[0].state;
					lhs.wrt = rhs[0].wrt;
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
					d = d == null ? d : d.combine(flipRight ? rhs[1].state.flip() : rhs[1].state);
					d = d == null ? init : init.combine(d);

					if (d != lhs.state || (rhs[0].wrt == rhs[1].wrt && rhs[0].wrt != lhs.wrt)) {
						lhs.state = d;
						lhs.wrt = init != Direction.Neither ? inst : rhs[0].wrt == rhs[1].wrt ? rhs[0].wrt : null;
						return CHANGED;
					}
				}

				return NOT_CHANGED;
			}

			@Override
			public int hashCode() {
				return 6745836 * init.hashCode() * (flipRight ? 1 : -1);
			}

			@Override
			public boolean equals(Object o) {
				return o.getClass() == this.getClass() && init == ((BinaryOperator) o).init
						&& flipRight == ((BinaryOperator) o).flipRight;
			}

			@Override
			public String toString() {
				return "rounding bin op " + init + " " + flipRight;
			}

		}

		private class RoundUpDetectingAddOperator extends BinaryOperator {
			RoundUpDetectingAddOperator(SSAInstruction inst) {
				super(false, Direction.Neither, inst);
			}

			boolean inCycle(int v1, int v2) {
				SSAInstruction d1 = du.getDef(v1);
				SSAInstruction d2 = du.getDef(v2);
				return d1 != null && 
					d2 != null &&
					getDeriving(d1).contains(d2) &&
					getDeriving(d2).contains(d1);
			}
			
			boolean isDivDown(RoundingVariable v) {
				return v != null && v.state == Direction.Down && v.wrt != null && v.wrt.getDef() == v.vn
						&& du.getDef(v.vn) instanceof SSABinaryOpInstruction
						&& ((SSABinaryOpInstruction) du.getDef(v.vn))
								.getOperator() == IBinaryOpInstruction.Operator.DIV;
			}

			@Override
			public byte evaluate(RoundingVariable lhs, RoundingVariable[] rhs) {
				if (isDivDown(rhs[0]) && rhs[1].state == Direction.Neither && !inCycle(lhs.vn, rhs[1].vn)) {
					if (lhs.state != Direction.Up) {
						lhs.state = Direction.Up;
						lhs.wrt = rhs[0].wrt;
						return CHANGED;
					}
				} else if (isDivDown(rhs[1]) && rhs[0].state == Direction.Neither && !inCycle(lhs.vn, rhs[0].vn)) { 
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
				return d.hashCode() * 668976;
			}

			@Override
			public boolean equals(Object o) {
				return o != null && getClass() == o.getClass() && d.equals(((ConstantOperator) o).d);
			}

			@Override
			public String toString() {
				return "constant " + d;
			}
		};

		private final CGNode n;
		private final IR ir;
		private final DefUse du;
		private final DefUseGraph dug;
		private final List<Direction> parameters;

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
		 * private Set<SSAInstruction> getQuotientRelated(SSABinaryOpInstruction div) {
		 * return getDerived(div); }
		 */

		private static MutableIntSet getRelatedValues(int startValue, Set<SSAInstruction> related, boolean forward) {
			return IntSetUtil.make(IntStream.concat(
					related.stream()
							.map(inst -> (forward ? IntStream.of(inst.getDef()).filter(i -> i > 0)
									: IntStream.range(0, inst.getNumberOfUses()).map(i -> inst.getUse(i))))
							.reduce((a, b) -> IntStream.concat(a, b)).orElse(IntStream.empty()),
					IntStream.of(startValue)).distinct().toArray());
		}

		private ControlDependenceGraph<ISSABasicBlock> cdg = null;
		
		private Set<ISSABasicBlock> deadBlocks = HashSetFactory.make();
		
		private void gatherControlDeps(int vn, boolean trueBranch) {
			du.getUses(vn).forEachRemaining(inst -> { 
				if (inst instanceof SSAConditionalBranchInstruction) {
					SSACFG cfg = ir.getControlFlowGraph();
					if (cdg == null) {
						cdg = new ControlDependenceGraph<>(cfg, true);
					}
					
					SSACFG.BasicBlock pb = cfg.getBlockForInstruction(inst.iIndex());					
					ISSABasicBlock db = trueBranch? Util.getNotTakenSuccessor(cfg, pb): Util.getTakenSuccessor(cfg, pb);
					cfg.getSuccNodes(pb).forEachRemaining(sb -> {
						if (cdg.getEdgeLabels(pb, sb).contains(db)) {
							System.err.println("dead block " + sb);
							deadBlocks.addAll(DFS.getReachableNodes(cdg, Collections.singleton(sb)));
						}
					});
				}
			});
		}
		
		public RoundingInference(List<Direction> parameters, Set<Pair<CGNode, List<Direction>>> ongoing, CGNode n)
				throws CancelException {
			ir = n.getIR();
			du = n.getDU();
			this.parameters = parameters;
			this.n = n;
			this.dug = new DefUseGraph(ir);

			for(int i = 0; i < n.getMethod().getNumberOfParameters(); i++) {
				final int stupidi = i;
				ContextItem k = n.getContext().get(ContextKey.PARAMETERS[i]);
				if (k instanceof SingleInstanceFilter && ((SingleInstanceFilter)k).getInstance() instanceof ConstantKey) {
					InstanceKey ik = ((SingleInstanceFilter)k).getInstance();
					du.getUses(i+1).forEachRemaining(use -> { 
						if (use instanceof SSABinaryOpInstruction && ((SSABinaryOpInstruction)use).getOperator() == CAstBinaryOp.EQ) {
							int otherV = use.getUse(0) == stupidi+1? use.getUse(1): use.getUse(0);
							PointerKey otherKey = PA.getHeapModel().getPointerKeyForLocal(n, otherV);
							OrdinalSet<InstanceKey> otherObjs = PA.getPointsToSet(otherKey);
							if (otherObjs.contains(ik) && otherObjs.size()==1) {
								gatherControlDeps(use.getDef(), false);
							} else {
								if (Streams.stream(otherObjs)
										.filter(ok -> ok.getConcreteType().equals(ik.getConcreteType()) &&
												      (!(ok instanceof ConstantKey<?>) ||
												       ((ConstantKey<?>)ik).getValue().equals(((ConstantKey<?>)ok).getValue())))
										.findAny()
										.isEmpty()) {
									}
								gatherControlDeps(use.getDef(), true);
							}
						}
					});
					System.err.println(deadBlocks);
				}
			}
			
			class CallOperator extends AbstractOperator<RoundingVariable> {
				private final SSAInvokeInstruction callInst;

				public CallOperator(SSAInvokeInstruction inst) {
					this.callInst = inst;
				}

				@Override
				public byte evaluate(RoundingVariable lhs, RoundingVariable[] rhs) {
					List<Direction> args = new ArrayList<>(callInst.getNumberOfUses());
					for (int i = 0; i < callInst.getNumberOfUses(); i++) {
						args.add(getVariable(callInst.getUse(i)).state);
					}

					Direction d = Direction.Neither;
					for (CGNode cgn : CG.getPossibleTargets(n, callInst.getCallSite())) {
						Pair<CGNode, List<Direction>> key = Pair.make(cgn, args);
						if (!ongoing.contains(key)) {
							if (!directionalCalls.containsKey(key)) {
								Set<Pair<CGNode, List<Direction>>> x = HashSetFactory.make(ongoing);
								x.add(key);
								try {
									RoundingInference child = new RoundingInference(args, x, cgn);
								} catch (CancelException e) {
									assert false : e;
								}
							}
							if (directionalCalls.containsKey(key) && directionalCalls.get(key).containsKey(null)) {
								d = d.meet(directionalCalls.get(key).get(null));
							}
						}
					}

					if (d != lhs.state) {
						lhs.state = d;
						return CHANGED;
					} else {
						return NOT_CHANGED;
					}
				}

				@Override
				public int hashCode() {
					return callInst.hashCode() * 17;
				}

				@Override
				public boolean equals(Object o) {
					return o != null && o.getClass() == getClass() && callInst.equals(((CallOperator) o).callInst);
				}

				@Override
				public String toString() {
					return "call " + callInst;
				}

			}

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
						result = new RoundUpDetectingAddOperator(instruction);

					} else if (op == IBinaryOpInstruction.Operator.MUL || op == IShiftInstruction.Operator.SHL) {
						result = new BinaryOperator(false, Direction.Neither);

					} else if (op == IBinaryOpInstruction.Operator.DIV) {
						Set<SSAInstruction> divisor = getDivisorRelated(instruction);
						
						Set<SSAInstruction> dividend = getDividendRelated(instruction);
						Set<SSAInstruction> dividendAddends = dividend.stream()
							.filter(inst -> inst instanceof SSABinaryOpInstruction && ((SSABinaryOpInstruction)inst).getOperator() == IBinaryOpInstruction.Operator.ADD)
							.map(inst -> getDeriving(inst))
							.reduce((l, r) -> Sets.union(l,  r))
							.orElse(Collections.emptySet());
						
						MutableIntSet bothValues = getRelatedValues(instruction.getUse(1), divisor, false);
						bothValues.intersectWith(getRelatedValues(instruction.getUse(0), dividendAddends, false));
						
						Direction d = bothValues.isEmpty() ? Direction.Down : Direction.Up;

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

				@Override
				public void visitInvoke(SSAInvokeInstruction inst) {
					if (inst.hasDef()) {
						result = new CallOperator(inst);
					}
				}

			}

			class RoundingVariableFactory implements VariableFactory<RoundingVariable> {
				private boolean hasReturn(int vn) {
					Iterator<SSAInstruction> is = du.getUses(vn);
					while (is.hasNext()) {
						if (is.next() instanceof SSAReturnInstruction) {
							return true;
						}
					}
					return false;
				}

				@Override
				public IVariable<RoundingVariable> makeVariable(int valueNumber) {
					RoundingVariable v;
					if (ir.getSymbolTable().isConstant(valueNumber)) {
						v = new RoundingVariable(valueNumber, Direction.Neither, null);

					} else if (valueNumber <= parameters.size()) {
						v = new RoundingVariable(valueNumber, parameters.get(valueNumber - 1), null);

					} else if (du.getDef(valueNumber) instanceof SSAAbstractInvokeInstruction) {
						v = new RoundingVariable(valueNumber, Direction.Neither, du.getDef(valueNumber));

					} else {
						v = new RoundingVariable(valueNumber, Direction.Neither, null);
					}

					if (hasReturn(valueNumber)) {
						result.add(v);
					}

					return v;
				}

			}

			init(ir, new RoundingVariableFactory(), new RoundingOperatorFactory());
			solve(null);

			Pair<CGNode, List<Direction>> key = Pair.make(n, parameters);
			rawResults.put(key, getRoundingResult());
			directionalCalls.put(key, getResultOrResults());
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
			return result.stream().filter(x -> x.state != null).map(x -> x.state).reduce(Direction::meet)
					.orElse(Direction.Neither);
		}

		private Map<FieldReference, Direction> unpackTuple(RoundingVariable x) {
			int maybeTuple = x.vn;
			Map<FieldReference, Direction> result = HashMapFactory.make();
			ir.iterateAllInstructions().forEachRemaining(inst -> {
				if (inst instanceof SSAPutInstruction) {
					SSAPutInstruction p = (SSAPutInstruction) inst;
					if (p.getRef() == maybeTuple) {
						Direction d = getVariable(p.getVal()).state;
						if (d != null) {
							if (result.containsKey(p.getDeclaredField())) {
								result.put(p.getDeclaredField(), d.meet(result.get(p.getDeclaredField())));
							} else {
								result.put(p.getDeclaredField(), d);
							}
						}
					}
				}
			});
			return result;
		}

		private Map<FieldReference, Direction> reduceTuples(Map<FieldReference, Direction> l,
				Map<FieldReference, Direction> r) {
			Map<FieldReference, Direction> result = HashMapFactory.make();
			for (FieldReference lk : l.keySet()) {
				if (!r.containsKey(lk)) {
					result.put(lk, l.get(lk));
				} else {
					result.put(lk, l.get(lk).meet(r.get(lk)));
				}
			}
			for (FieldReference rk : r.keySet()) {
				if (!l.containsKey(rk)) {
					result.put(rk, r.get(rk));
				}
			}
			return result;
		}

		public Map<FieldReference, Direction> getResults() {
			return result.stream().map(this::unpackTuple).reduce(this::reduceTuples).orElse(Collections.emptyMap());
		}

		public Map<FieldReference, Direction> getResultOrResults() {
			Map<FieldReference, Direction> result = getResults();
			if (result.isEmpty()) {
				result = Collections.singletonMap(null, getResult());
			}
			return result;
		}

		@Override
		public String toString() {
			return super.toString() + "returning " + result;
		}

		public interface Result {
			Direction[][] getOperandRounding();

			Direction[][] getResultRounding();

			JSONObject toJSON();

			NumberedLabeledGraph<JSONObject, Position> toGraph();

			JSONObject makeGraph(NumberedLabeledGraph<JSONObject,Position> g, Map<Pair<CGNode, List<Direction>>, JSONObject> startedSoFar);
		
			Map<FieldReference, Direction> getReturnRounding();
		}

		public Result getRoundingResult() {
			Direction[][] operands = new Direction[ir.getInstructions().length][];
			Direction[][] results = new Direction[ir.getInstructions().length][];
			for (SSAInstruction inst : ir.getInstructions()) {
				if (inst != null) {
					Direction[] uses = operands[inst.iIndex()] = new Direction[inst.getNumberOfUses()];
					for (int i = 0; i < uses.length; i++) {
						uses[i] = getVariable(inst.getUse(i)).state;
					}
					Direction[] defs = results[inst.iIndex()] = new Direction[inst.getNumberOfDefs()];
					for (int i = 0; i < defs.length; i++) {
						defs[i] = getVariable(inst.getDef(i)).state;
					}
				}
			}
			return new Result() {
				@Override
				public Direction[][] getOperandRounding() {
					return operands;
				}

				@Override
				public Direction[][] getResultRounding() {
					return results;
				}

				@Override
				public String toString() {
					NumberedLabeledGraph<JSONObject,Position> out = new SlowSparseNumberedLabeledGraph<>();
					makeGraph(out, HashMapFactory.make());
					StringBuffer sb = new StringBuffer();		
					out.forEach(n -> { 
						sb.append(out.getNumber(n) + ": function " + n.getString("method"));
						if (n.has("methodPosition")) {
							sb.append(" (").append(n.getString("methodPosition")).append(")");
						}
						sb.append('\n');
						
						JSONArray parameters = n.getJSONArray("parameters");
						for(int i = 0; i < parameters.length(); i++) {
							JSONObject p = parameters.getJSONObject(i);
							if (p.has("source")) {
								sb.append("   ").append(p.getString("position")).append(" ").append(p.getString("source")).append(" --> ").append(p.get("rounding")).append('\n');
							}
						}
						
						JSONObject roundings = n.getJSONObject("roundings");
						for(String pos : roundings.keySet()) {
							JSONObject r = roundings.getJSONObject(pos);
							if (Direction.Neither != r.get("rounding")) {
								sb.append(" ").append(pos).append(": ").append(r.get("source")).append(" --> ").append(r.get("rounding"));
								if (r.has("expr")) {
									sb.append(" (use in ").append(r.get("expr")).append(")");
								}
								sb.append('\n');
							}
						}

						if (n.has("return")) {
							sb.append(" return " + n.get("return"));
							sb.append("\n");
						}
						
						if (out.getSuccNodeCount(n) > 0) {
							sb.append(" --> ").append(out.getSuccNodeNumbers(n));
						}
						
						sb.append("\n");
					});
					
					return sb.toString();
				}

				public JSONObject toJSON() {
					JSONObject o = new JSONObject();
					o.put("method", ir.getMethod().toString());
					DebuggingInformation dbg = ((AstMethod) ir.getMethod()).debugInfo();
					if (ir.getMethod() instanceof AstMethod) {
						o.put("methodPosition", dbg.getCodeBodyPosition().getURL().getPath() + ":" + JSONOutput.toLocalPos(dbg.getCodeBodyPosition()));
					}
					JSONArray params;
					o.put("parameters", params = new JSONArray(ir.getNumberOfParameters()));
					for (int i = 0; i < ir.getNumberOfParameters(); i++) {
						try {
							JSONObject p = new JSONObject();
							p.put("rounding", String.valueOf(getVariable(i + 1).state));
							params.put(p);
							Position pos = dbg.getParameterPosition(i);
							if (pos != null) {
								p.put("position", JSONOutput.toLocalPos(pos));
								p.put("source", new SourceBuffer(pos).toString());
							}
						} catch (IOException e) {
							assert false : e;
						}
					}
					JSONObject roundings = new JSONObject();
					o.put("roundings", roundings);
					for (int i = 0; i < operands.length; i++) {
						if (operands[i] != null) {
							for (int j = 0; j < operands[i].length; j++) {
								if (operands[i][j] != null) {
									expressionToJSON(operands, dbg, roundings, i, j, true);
								}
							}
						}
						if (results[i] != null) {
							for (int j = 0; j < results[i].length; j++) {
								if (results[i][j] != null) {
									expressionToJSON(results, dbg, roundings, i, j, false);
								}
							}
						}
					}
					Map<FieldReference, Direction> ret = getResultOrResults();
					o.put("return", String.valueOf(ret.containsKey(null)? ret.get(null): ret));

					return o;
				}

				public NumberedLabeledGraph<JSONObject,Position> toGraph() {
					NumberedLabeledGraph<JSONObject,Position> out = new SlowSparseNumberedLabeledGraph<>();
					makeGraph(out, HashMapFactory.make());
					return out;
				}
					
				public JSONObject makeGraph(NumberedLabeledGraph<JSONObject,Position> g, Map<Pair<CGNode, List<Direction>>, JSONObject> startedSoFar) {
					Pair<CGNode, List<Direction>> me = Pair.make(n, parameters);
					if (!startedSoFar.containsKey(me)) {
						DebuggingInformation dbg = ((AstMethod) ir.getMethod()).debugInfo();
						JSONObject thisOne = toJSON();
						startedSoFar.put(me, thisOne);
						g.addNode(thisOne);

						ir.iterateAllInstructions().forEachRemaining(inst -> {
							if (inst instanceof SSAInvokeInstruction) {
								List<Direction> args = new ArrayList<>(inst.getNumberOfUses());
								for (int i = 0; i < inst.getNumberOfUses(); i++) {
									args.add(getVariable(inst.getUse(i)).state);
								}
								for (CGNode callee : CG.getPossibleTargets(n,
										((SSAInvokeInstruction) inst).getCallSite())) {
									Pair<CGNode, List<Direction>> key = Pair.make(callee, args);
									if (rawResults.containsKey(key) && !startedSoFar.containsKey(key)) {
									  g.addEdge(thisOne, rawResults.get(key).makeGraph(g, startedSoFar), dbg.getInstructionPosition(inst.iIndex()));
									}
								}
							}
						});
						return thisOne;
					} else { 
						return startedSoFar.get(me);
					}
					
				}

				private void expressionToJSON(Direction[][] data, DebuggingInformation dbg, JSONObject roundings,
						int i, int j, boolean use) {
					if (ir.getMethod() instanceof AstMethod) {
						Position p = use? dbg.getOperandPosition(i, j): dbg.getInstructionPosition(i);
						if (p != null && (!IMPLICIT_NEITHER || data[i][j] != Direction.Neither)) {
							try {
								String k = JSONOutput.toLocalPos(p);
								JSONObject x = new JSONObject();
								roundings.put(k, x);
								x.put("rounding", data[i][j].toString());
								x.put("source", new SourceBuffer(p).toString());
								if (use) {
									x.put("expr", new SourceBuffer(dbg.getInstructionPosition(i)).toString());
								}
							} catch (IOException e) {
								assert false : e;
							}
						}
					}
				}

				@Override
				public Map<FieldReference, Direction> getReturnRounding() {
					return getResultOrResults();
				}
			};
		}
	}

	public Result analyzeForNode(CallGraph cg, CGNode n) throws CancelException {
		List<Direction> params = IntStream.range(0, n.getMethod().getNumberOfParameters()).mapToObj(i -> Direction.Neither).toList();
		Pair<CGNode,List<Direction>> key = Pair.make(n, params);
		if (! rawResults.containsKey(key)) {
			RoundingInference ri = new RoundingInference(params, HashSetFactory.make(), n);
			Result G = ri.getRoundingResult();
			return G;
		} else {
			return rawResults.get(key);
		}
	}
}