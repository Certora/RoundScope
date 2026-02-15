package com.certora.wala.cast.solidity.ipa.callgraph;

import java.util.Map;
import java.util.Set;

import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.ibm.wala.cast.loader.AstFunctionClass;
import com.ibm.wala.classLoader.IClass;
import com.ibm.wala.classLoader.IMethod;
import com.ibm.wala.core.util.strings.Atom;
import com.ibm.wala.ipa.callgraph.Entrypoint;
import com.ibm.wala.ipa.callgraph.impl.AbstractRootMethod;
import com.ibm.wala.ipa.callgraph.impl.DefaultEntrypoint;
import com.ibm.wala.ipa.cha.IClassHierarchy;
import com.ibm.wala.ssa.SSAAbstractInvokeInstruction;
import com.ibm.wala.ssa.SSANewInstruction;
import com.ibm.wala.types.FieldReference;
import com.ibm.wala.types.MethodReference;
import com.ibm.wala.types.TypeReference;
import com.ibm.wala.util.collections.HashSetFactory;
import com.ibm.wala.util.collections.Pair;

public class LinkedEntrypoint extends DefaultEntrypoint {

	private final Map<Pair<Atom, TypeReference>, TypeReference> linkage;
	private final IClass selfType;
	
	public LinkedEntrypoint(IMethod method, IClassHierarchy cha, IClass selfType, Map<Pair<Atom,TypeReference>,TypeReference> linkage) {
		super(method, cha);
		this.linkage = linkage;
		this.selfType = selfType;
	}

	public LinkedEntrypoint(MethodReference method, IClassHierarchy cha,IClass selfType,  Map<Pair<Atom,TypeReference>,TypeReference> linkage) {
		super(method, cha);
		this.linkage = linkage;
		this.selfType = selfType;
	}

	@Override
	public SSAAbstractInvokeInstruction addCall(AbstractRootMethod m) {
		SSAAbstractInvokeInstruction call = super.addCall(m);
		int functionSelf = call.getUse(0);
		int objSelf = m.addAllocation(selfType.getReference()).getDef();
		m.addSetInstance(FieldReference.findOrCreate(call.getDeclaredTarget().getDeclaringClass(), Atom.findOrCreateUnicodeAtom("self"), selfType.getReference()), functionSelf, objSelf);
		linkage.forEach((x, y) -> { 
			if (selfType.getReference().equals(x.snd)) {
				FieldReference fr = FieldReference.findOrCreate(x.snd, x.fst, y);
				SSANewInstruction alloc = m.addAllocation(y);
				m.addSetInstance(fr, objSelf, alloc.getDef());
			}
		});
		
		return call;
	}

	@Override
	public TypeReference[] getParameterTypes(int i) {
		return new TypeReference[] { method.getParameterType(i) };
	}

	public static Set<Entrypoint> getContractEntrypoints(Map<Pair<Atom,TypeReference>,TypeReference> linkage, IClassHierarchy cha) {
		Set<Entrypoint> es = HashSetFactory.make();
		IClass contractClass = cha.lookupClass(SolidityTypes.contract);
		IClass interfaceClass = cha.lookupClass(SolidityTypes.interfce);
		cha.forEach(cl -> { 
			if (cl != contractClass && (cha.isAssignableFrom(contractClass, cl))) {
				cl.getDeclaredInstanceFields().forEach(m -> { 
					IClass fieldClass = cha.lookupClass(TypeReference.findOrCreate(SolidityTypes.solidity, m.getName().toString()));
					if (fieldClass != null && cha.isSubclassOf(fieldClass, cha.lookupClass(SolidityTypes.function))) {
						AstFunctionClass afc = (AstFunctionClass) fieldClass;
						if (afc.isPublic() && !afc.isAbstract()) {
							es.add(new LinkedEntrypoint(afc.getCodeBody(), cha, cl, linkage));
						}
					}
				});
			}
		});
		return es;
	}
}
