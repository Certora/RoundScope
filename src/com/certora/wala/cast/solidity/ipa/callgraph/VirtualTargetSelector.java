package com.certora.wala.cast.solidity.ipa.callgraph;

import static com.certora.wala.cast.solidity.loader.SolidityLoader.allSupers;
import static com.certora.wala.cast.solidity.loader.SolidityLoader.allSupersIncludingSelf;

import java.util.Set;
import java.util.function.Consumer;

import org.jspecify.annotations.Nullable;

import com.certora.wala.cast.solidity.loader.InterfaceType;
import com.certora.wala.cast.solidity.loader.SolidityLoader.TypedCodeBody;
import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.ibm.wala.cast.loader.CAstAbstractModuleLoader.DynamicCodeBody;
import com.ibm.wala.classLoader.CallSiteReference;
import com.ibm.wala.classLoader.IClass;
import com.ibm.wala.classLoader.IMethod;
import com.ibm.wala.core.util.strings.Atom;
import com.ibm.wala.fixpoint.UnaryOperator;
import com.ibm.wala.ipa.callgraph.AnalysisOptions;
import com.ibm.wala.ipa.callgraph.CGNode;
import com.ibm.wala.ipa.callgraph.MethodTargetSelector;
import com.ibm.wala.ipa.callgraph.propagation.InstanceKey;
import com.ibm.wala.ipa.callgraph.propagation.PointerKey;
import com.ibm.wala.ipa.callgraph.propagation.PointsToSetVariable;
import com.ibm.wala.ipa.callgraph.propagation.SSAPropagationCallGraphBuilder;
import com.ibm.wala.shrike.shrikeBT.IInvokeInstruction.Dispatch;
import com.ibm.wala.ssa.SSAAbstractInvokeInstruction;
import com.ibm.wala.types.TypeName;
import com.ibm.wala.types.TypeReference;
import com.ibm.wala.util.collections.HashSetFactory;
import com.ibm.wala.util.intset.IntSetUtil;
import com.ibm.wala.util.intset.MutableIntSet;
import com.ibm.wala.util.intset.OrdinalSet;

public class VirtualTargetSelector implements MethodTargetSelector {
	private final SSAPropagationCallGraphBuilder cgBuilder;
	private final MethodTargetSelector parent;

	public VirtualTargetSelector(SSAPropagationCallGraphBuilder cgBuilder, AnalysisOptions options) {
		this.cgBuilder = cgBuilder;
		parent = options.getMethodTargetSelector();
	}

	class IndirectOp extends UnaryOperator<PointsToSetVariable> {
		private final MutableIntSet oldValue = IntSetUtil.make();
		private final CGNode target;
				
		private IndirectOp(CGNode target) {
			this.target = target;
		}

		@Override
		public byte evaluate(@Nullable PointsToSetVariable lhs, PointsToSetVariable rhs) {
			if (rhs.getValue() != null &&  !oldValue.equals(rhs.getValue())) {
				oldValue.addAll(rhs.getValue());
				cgBuilder.markChanged(target);
				return CHANGED;
			} else {
				return NOT_CHANGED;
			}
		}

		@Override
		public int hashCode() {
			return target.hashCode();
		}

		@Override
		public boolean equals(Object o) {
			return o.getClass() == getClass() && target==((IndirectOp)o).target;
		}

		@Override
		public String toString() {
			return "dependence for self for " + target;
		}
	};
	
	@Override
	public IMethod getCalleeTarget(CGNode caller, CallSiteReference site, IClass receiver) {
		if (site.getDeclaredTarget().toString().contains("_onSwapGivenOut")) {
			System.err.println("found it");
		}
		if (receiver instanceof TypedCodeBody && 
			(((TypedCodeBody)receiver).isVirtual() || 
			 site.getInvocationCode() == Dispatch.SPECIAL ||
			 ((TypedCodeBody)receiver).getSelfType() instanceof InterfaceType)) {
			//System.err.println("@@@@ " + receiver + " " + ((TypedCodeBody)receiver).getSelf());						
			Set<IMethod> targets = HashSetFactory.make();
			for(SSAAbstractInvokeInstruction call : caller.getIR().getCalls(site)) {
				PointerKey self = cgBuilder.getPointerKeyFactory().getPointerKeyForLocal(caller, call.getReceiver());
				OrdinalSet<InstanceKey> selfTypes = cgBuilder.getPointerAnalysis().getPointsToSet(self);
				selfTypes.forEach(selfKey -> { 
					if (selfKey.getConcreteType() instanceof TypedCodeBody) {
						PointerKey selfField = cgBuilder.getPointerKeyFactory().getPointerKeyForInstanceField(selfKey, selfKey.getConcreteType().getField(Atom.findOrCreateUnicodeAtom("self")));	
						cgBuilder.getPropagationSystem().newSideEffect(new IndirectOp(caller), selfField);
						OrdinalSet<InstanceKey> funTypes = cgBuilder.getPointerAnalysis().getPointsToSet(selfField);
						funTypes.forEach(new Consumer<InstanceKey>() {

							boolean getFunctionType(IClass sc) {
								String nm = sc.getName() + "." + ((TypedCodeBody)selfKey.getConcreteType()).functionName();
								IClass f = caller.getClassHierarchy().lookupClass(TypeReference.findOrCreate(SolidityTypes.solidity, TypeName.string2TypeName(nm)));
								if (f instanceof DynamicCodeBody && ((DynamicCodeBody)f).getCodeBody() != null) {
									targets.add(((DynamicCodeBody)f).getCodeBody());
									return true;
								} else {
									return false;
								}
							}

							@Override
							public void accept(InstanceKey fk) {
								{
									if (site.getInvocationCode() == Dispatch.SPECIAL) {
										allSupers(fk.getConcreteType()).forEach(x -> getFunctionType(x));										
									} else {
										if (! getFunctionType(fk.getConcreteType())) {
											allSupersIncludingSelf(fk.getConcreteType()).forEach(x -> getFunctionType(x));
										}
									}
								}
							}
						});
					}
				});
			}
			System.err.println("@@@ " + targets);
			if (targets.isEmpty()) {
				return null;
			} else if (targets.size() == 1) {
				return targets.iterator().next();
			} else {
				System.err.println("what is this?");
				return null;
			}
		}
		
		IMethod callee = parent.getCalleeTarget(caller, site, receiver);
		return callee;
	}
}
