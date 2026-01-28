package com.certora.wala.analysis.defuse;

import java.util.Iterator;
import java.util.stream.IntStream;
import java.util.stream.Stream;
import java.util.stream.StreamSupport;

import com.ibm.wala.ssa.DefUse;
import com.ibm.wala.ssa.IR;
import com.ibm.wala.ssa.SSAInstruction;
import com.ibm.wala.util.collections.EmptyIterator;
import com.ibm.wala.util.collections.IteratorUtil;
import com.ibm.wala.util.graph.AbstractNumberedGraph;
import com.ibm.wala.util.graph.NumberedEdgeManager;
import com.ibm.wala.util.graph.NumberedNodeManager;
import com.ibm.wala.util.intset.IntSet;
import com.ibm.wala.util.intset.IntSetUtil;
import com.ibm.wala.util.intset.MutableIntSet;

public class DefUseGraph extends AbstractNumberedGraph<Integer> {
	private final IR ir;
	private final DefUse du;
	
	public DefUseGraph(IR ir) {
		this.du = new DefUse(this.ir = ir);
	}
	
	public IR ir() {
		return ir;
	}

	public DefUse du() {
		return du;
	}

	@Override
	protected NumberedNodeManager<Integer> getNodeManager() {
		return new NumberedNodeManager<>() {

			@Override
			public Stream<Integer> stream() {
				return IntStream.range(1, getMaxNumber()).boxed();
			}

			@Override
			public int getNumberOfNodes() {
				return ir.getSymbolTable().getMaxValueNumber();
			}

			@Override
			public void addNode(Integer n) {
				throw new UnsupportedOperationException();
			}

			@Override
			public void removeNode(Integer n) throws UnsupportedOperationException {
				throw new UnsupportedOperationException();
			}

			@Override
			public boolean containsNode(Integer n) {
				return n > 0 && n <= ir.getSymbolTable().getMaxValueNumber();
			}

			@Override
			public int getNumber(Integer N) {
				return N;
			}

			@Override
			public Integer getNode(int number) {
				return number;
			}

			@Override
			public int getMaxNumber() {
				return ir.getSymbolTable().getMaxValueNumber();
			}

			@Override
			public Iterator<Integer> iterateNodes(IntSet s) {
				return stream().filter(i -> s.contains(i)).iterator();
			}
		};
	}

	@Override
	protected NumberedEdgeManager<Integer> getEdgeManager() {
		return new NumberedEdgeManager<>() {

			private <X> Stream<X> toStream(Iterator<X> i) {
				Iterable<X> s = () -> i;
				return StreamSupport.stream(s.spliterator(), false);			
			}
			
			@Override
			public Iterator<Integer> getSuccNodes(Integer n) {
				return toStream(du.getUses(n)).filter(inst -> inst.hasDef()).map(inst -> inst.getDef()).iterator();
			}

			@Override
			public int getSuccNodeCount(Integer n) {
				return IteratorUtil.count(du.getUses(n));
			}

			@Override
			public Iterator<Integer> getPredNodes(Integer n) {
				SSAInstruction def = du.getDef(n);
				if (def == null) {
					return EmptyIterator.instance();
				} else {
					return IntStream.range(0, def.getNumberOfUses()).map(i -> def.getUse(i)).filter(i -> i > 0).iterator();
				}					
			}

			@Override
			public int getPredNodeCount(Integer N) {
				SSAInstruction def = du.getDef(N);
				if (N == null) {
					return 0;
				} else {
					return def.getNumberOfUses();
				}
			}

			@Override
			public void addEdge(Integer src, Integer dst) {
				throw new UnsupportedOperationException();
				
			}

			@Override
			public void removeEdge(Integer src, Integer dst) throws UnsupportedOperationException {
				throw new UnsupportedOperationException();
			}

			@Override
			public void removeAllIncidentEdges(Integer node) throws UnsupportedOperationException {
				throw new UnsupportedOperationException();
			}

			@Override
			public void removeIncomingEdges(Integer node) throws UnsupportedOperationException {
				throw new UnsupportedOperationException();
			}

			@Override
			public void removeOutgoingEdges(Integer node) throws UnsupportedOperationException {
				throw new UnsupportedOperationException();
			}

			@Override
			public boolean hasEdge(Integer src, Integer dst) {
				return getSuccNodeNumbers(src).contains(dst);
			}

			@Override
			public IntSet getSuccNodeNumbers(Integer node) {
				MutableIntSet x = IntSetUtil.make();
				getSuccNodes(node).forEachRemaining(i -> x.add(i));
				return x;
			}

			@Override
			public IntSet getPredNodeNumbers(Integer node) {
				MutableIntSet x = IntSetUtil.make();
				getPredNodes(node).forEachRemaining(i -> x.add(i));
				return x;
			}
			
		};
	}
	
}