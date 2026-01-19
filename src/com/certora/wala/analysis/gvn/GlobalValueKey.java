package com.certora.wala.analysis.gvn;

import java.util.Arrays;
import java.util.List;
import java.util.Objects;

import com.ibm.wala.ipa.slicer.Statement;
import com.ibm.wala.shrike.shrikeBT.IBinaryOpInstruction;
import com.ibm.wala.shrike.shrikeBT.IComparisonInstruction;
import com.ibm.wala.shrike.shrikeBT.IUnaryOpInstruction;
import com.ibm.wala.types.TypeReference;

public class GlobalValueKey<T> {

	public static interface Operator {
		
	}

	private final Operator op;
	private final List<GlobalValueKey<T>> values;
	
	public GlobalValueKey(GlobalValueKey<T> elt) {
		op = null;
		values = Arrays.asList(elt);
	}

	@SafeVarargs
	public GlobalValueKey(Operator op, GlobalValueKey<T>... values) {
		this.op = op;
		this.values = Arrays.asList(values);
	}
	
	public int hashCode() {
		int c = values.hashCode();
		if (op != null) {
			c *= op.hashCode();
		}
		return c;
	}
	
	@SuppressWarnings("unchecked")
	public boolean equals(Object o) {
		if (o.getClass() != getClass()) {
			return false;
		}
		if ( !((op == null)? ((GlobalValueKey<T>)o).op == null: op.equals(((GlobalValueKey<T>)o).op))) {
			return false;
		}
		return values.equals(((GlobalValueKey<T>)o).values);
	}
	
	public static class Op implements Operator {
		private final Object op;

		public Op() {
			this.op = null;
		}
		
		public Op(Integer v) {
			this.op = v;
			
		}
		public Op(IBinaryOpInstruction.IOperator op) {
			this.op = op;
		}
		
		public Op(IUnaryOpInstruction.IOperator op) {
			this.op = op;
		}
		
		public Op(TypeReference op) {
			this.op = op;
		}

		public Op(IComparisonInstruction.Operator op) {
			this.op = op;
		}

		@Override
		public int hashCode() {
			return Objects.hash(op);
		}

		@Override
		public boolean equals(Object obj) {
			return obj.getClass() == getClass() &&
				(op == null)? 
					((Op)obj).op == null:
					((Op)obj).op.equals(op);
		}
	}

	public static class IR extends GlobalValueKey<Integer> {
		public static Op PURE_CALL = new Op() {
			public String toString() { return "pure call op"; }
		};
		
		
		public IR(GlobalValueKey<Integer> elt) {
			super(elt);
		}

		@SafeVarargs
		public IR(Op op, GlobalValueKey<Integer>... values) {
			super(op, values);
		}
	}
	
	public static class SDG extends GlobalValueKey<Statement> {

		@SafeVarargs
		public SDG(Op op, GlobalValueKey<Statement>... values) {
			super(op, values);
		}

		public SDG(GlobalValueKey<Statement> elt) {
			super(elt);
		}
			
	}
}
