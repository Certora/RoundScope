package com.certora.wala.analysis.gvn;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Set;

import com.certora.wala.analysis.gvn.GlobalValueKey.Op;
import com.ibm.wala.ipa.slicer.NormalStatement;
import com.ibm.wala.ipa.slicer.Statement;
import com.ibm.wala.ssa.IR;
import com.ibm.wala.ssa.SSAArrayLengthInstruction;
import com.ibm.wala.ssa.SSABinaryOpInstruction;
import com.ibm.wala.ssa.SSACheckCastInstruction;
import com.ibm.wala.ssa.SSAComparisonInstruction;
import com.ibm.wala.ssa.SSAConversionInstruction;
import com.ibm.wala.ssa.SSAInstanceofInstruction;
import com.ibm.wala.ssa.SSAInstruction;
import com.ibm.wala.ssa.SSAInvokeInstruction;
import com.ibm.wala.ssa.SSAPhiInstruction;
import com.ibm.wala.ssa.SSAPiInstruction;
import com.ibm.wala.ssa.SSAReturnInstruction;
import com.ibm.wala.ssa.SSAUnaryOpInstruction;
import com.ibm.wala.ssa.SymbolTable;
import com.ibm.wala.util.collections.HashMapFactory;
import com.ibm.wala.util.collections.HashSetFactory;
import com.ibm.wala.util.graph.Graph;

public abstract class GlobalValueNumbers<T> {
	Graph<T> G;
	
	protected Map<T,Set<T>> globalValueSets = HashMapFactory.make();
	
	protected abstract boolean process(T elt, Map<T, GlobalValueKey<T>> globalValues, Map<GlobalValueKey<T>, Set<T>> keySets);
	
	protected void init(Map<T, GlobalValueKey<T>> globalValues, Map<GlobalValueKey<T>, Set<T>> keySets) {
		
	}
	
	private static <T> void add(GlobalValueKey<T> k, T v, Map<GlobalValueKey<T>, Set<T>> keySet) {
		if (! keySet.containsKey(k)) {
			keySet.put(k, HashSetFactory.make());
		}
		keySet.get(k).add(v);
	}
	
	private boolean ready(T x, Map<T, GlobalValueKey<T>> globalValues ) {
		Iterator<T> y = G.getPredNodes(x);
		while(y.hasNext()) {
			if (! globalValues.containsKey(y.next())) {
				return false;
			}
		}
		return true;
	}
	
	private void analyze() {
		Map<T, GlobalValueKey<T>> globalValues = HashMapFactory.make();
		Map<GlobalValueKey<T>, Set<T>> keySets = HashMapFactory.make();
		init(globalValues, keySets);
		boolean changes;
		do {
			changes = false;
			for(T e : G) {
				if (ready(e, globalValues)) {
					changes |= process(e, globalValues, keySets);
				}
			}
		} while (changes);	
		
		for(Set<T> s : keySets.values()) {
			for(T e : s) {
				globalValueSets.put(e, s);
			}
		}
	}
	
	public String toString() {
		return "GVN:"+globalValueSets.toString();
	}
	
	GlobalValueNumbers(Graph<T> G) {
		this.G = G;
		analyze();
	}
	
	public boolean equivalent(T a, T b) {
		return globalValueSets.containsKey(a) && 
				globalValueSets.containsKey(b) && 
				globalValueSets.get(a) == globalValueSets.get(b);
	}
	
	public static class SDGValueNumbers extends GlobalValueNumbers<Statement> {

		SDGValueNumbers(Graph<Statement> G) {
			super(G);
		}

		@Override
		protected boolean process(Statement elt, Map<Statement, GlobalValueKey<Statement>> globalValues, Map<GlobalValueKey<Statement>, Set<Statement>> keySets) {
			switch (elt.getKind()) {
			case CATCH:
				break;
			case EXC_RET_CALLEE:
				break;
			case EXC_RET_CALLER:
				break;
			case HEAP_PARAM_CALLEE:
				break;
			case HEAP_PARAM_CALLER:
				break;
			case HEAP_RET_CALLEE:
				break;
			case HEAP_RET_CALLER:
				break;
			case METHOD_ENTRY:
				break;
			case METHOD_EXIT:
				break;
			case NORMAL:
				SSAInstruction inst = ((NormalStatement)elt).getInstruction();
				inst.visit(new SSAInstruction.Visitor() {

					private void visitOp(Op op) {
						List<GlobalValueKey<Statement>> args = new ArrayList<>();
						G.getPredNodes(elt).forEachRemaining(p -> args.add(globalValues.get(p)));
						@SuppressWarnings("unchecked")
						GlobalValueKey<Statement> me = new GlobalValueKey<Statement>(op, args.toArray(new GlobalValueKey[ args.size() ] ) );
						if (! globalValues.containsKey(elt)) {
							globalValues.put(elt, me);
						}
					}
					
					@Override
					public void visitBinaryOp(SSABinaryOpInstruction instruction) {
						visitOp(new Op(instruction.getOperator()));
					}

					@Override
					public void visitUnaryOp(SSAUnaryOpInstruction instruction) {
						visitOp(new Op(instruction.getOpcode()));
					}

					@Override
					public void visitConversion(SSAConversionInstruction instruction) {
						// TODO Auto-generated method stub
						super.visitConversion(instruction);
					}

					@Override
					public void visitComparison(SSAComparisonInstruction instruction) {
						// TODO Auto-generated method stub
						super.visitComparison(instruction);
					}

					@Override
					public void visitReturn(SSAReturnInstruction instruction) {
						// TODO Auto-generated method stub
						super.visitReturn(instruction);
					}

					@Override
					public void visitInvoke(SSAInvokeInstruction instruction) {
						// TODO Auto-generated method stub
						super.visitInvoke(instruction);
					}

					@Override
					public void visitArrayLength(SSAArrayLengthInstruction instruction) {
						// TODO Auto-generated method stub
						super.visitArrayLength(instruction);
					}

					@Override
					public void visitCheckCast(SSACheckCastInstruction instruction) {
						// TODO Auto-generated method stub
						super.visitCheckCast(instruction);
					}

					@Override
					public void visitInstanceof(SSAInstanceofInstruction instruction) {
						// TODO Auto-generated method stub
						super.visitInstanceof(instruction);
					}
				
				});
				break;
			case NORMAL_RET_CALLEE:
				break;
			case NORMAL_RET_CALLER:
				break;
			case PARAM_CALLEE:
				break;
			case PARAM_CALLER:
				break;
			case PHI:
				break;
			case PI:
				break;
			default:
				assert false : elt;
			}
			
			return false;
		}
	}
	
	public static class IRValueNumbers extends GlobalValueNumbers<Integer> {

		private IRValueNumbers(DefUseGraph G) {
			super(G);
		}
		
		public IRValueNumbers(IR ir) {
			super(new DefUseGraph(ir));
		}

		
		@Override
		protected void init(Map<Integer, GlobalValueKey<Integer>> globalValues, Map<GlobalValueKey<Integer>, Set<Integer>> keySets) {
			SymbolTable st = ((DefUseGraph)G).ir().getSymbolTable();
			for(int i = 1; i <= st.getMaxValueNumber(); i++) {
				if (st.isConstant(i) || i <= st.getNumberOfParameters()) {
					globalValues.put(i, new GlobalValueKey<Integer>(new Op(i)));
				}
			}
		}

		@Override
		protected boolean process(Integer elt, Map<Integer, GlobalValueKey<Integer>> globalValues, Map<GlobalValueKey<Integer>, Set<Integer>> keySets) {
			SSAInstruction def = ((DefUseGraph)G).du().getDef(elt);
			if (def == null) {
				if (globalValues.containsKey(elt) ) {
					return false;
				} else {
					globalValues.put(elt, new GlobalValueKey<Integer>(new Op(elt)));
					return true;
				}
			} else {
				return new SSAInstruction.Visitor() {
					private boolean changed = false;
					
					{
						def.visit(this);
					}

					private void visitOp(SSAInstruction inst, Op op) {
						@SuppressWarnings("unchecked")
						GlobalValueKey<Integer>[] operands = new GlobalValueKey[ inst.getNumberOfUses() ];
						for(int i = 0; i < inst.getNumberOfUses(); i++) {
							operands[i] = globalValues.get(inst.getUse(i));
						}
						GlobalValueKey<Integer> k = new GlobalValueKey<Integer>(op, operands);
						if (! keySets.containsKey(k)) {
							add(k, elt, keySets);
							globalValues.put(elt, k);
							changed = true;
						} else if (! globalValues.containsKey(elt)) {
							add(k, elt, keySets);
							globalValues.put(elt, globalValues.get(elt));
							changed = true;
						}
					}
					
					@Override
					public void visitBinaryOp(SSABinaryOpInstruction instruction) {
						visitOp(instruction, new Op(instruction.getOperator()));
					}

					@Override
					public void visitUnaryOp(SSAUnaryOpInstruction instruction) {
						visitOp(instruction, new Op(instruction.getOpcode()));
					}

					@Override
					public void visitConversion(SSAConversionInstruction instruction) {
						visitOp(instruction, new Op(instruction.getToType()));
					}

					@Override
					public void visitComparison(SSAComparisonInstruction instruction) {
						visitOp(instruction, new Op(instruction.getOperator()));
					}

					@Override
					public void visitInvoke(SSAInvokeInstruction instruction) {
						// TODO Auto-generated method stub
						super.visitInvoke(instruction);
					}

					@Override
					public void visitCheckCast(SSACheckCastInstruction instruction) {
						// TODO Auto-generated method stub
						super.visitCheckCast(instruction);
					}

					@Override
					public void visitInstanceof(SSAInstanceofInstruction instruction) {
						// TODO Auto-generated method stub
						super.visitInstanceof(instruction);
					}

					@Override
					public void visitPhi(SSAPhiInstruction instruction) {
						// TODO Auto-generated method stub
						super.visitPhi(instruction);
					}

					@Override
					public void visitPi(SSAPiInstruction instruction) {
						// TODO Auto-generated method stub
						super.visitPi(instruction);
					}
					
					
				}.changed;
			}
		}
	}
}
