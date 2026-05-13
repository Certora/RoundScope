package com.certora.wala.cast.solidity.ipa.callgraph;

import static com.certora.wala.cast.solidity.loader.SolidityLoader.allSupersIncludingSelf;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

import org.eclipse.lsp4j.jsonrpc.messages.Either;

import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.certora.wala.cast.solidity.util.CVLLinkageSpec;
import com.ibm.wala.cast.loader.AstFunctionClass;
import com.ibm.wala.classLoader.CallSiteReference;
import com.ibm.wala.classLoader.IClass;
import com.ibm.wala.classLoader.IField;
import com.ibm.wala.classLoader.IMethod;
import com.ibm.wala.core.util.strings.Atom;
import com.ibm.wala.ipa.callgraph.Entrypoint;
import com.ibm.wala.ipa.callgraph.impl.AbstractRootMethod;
import com.ibm.wala.ipa.callgraph.impl.DefaultEntrypoint;
import com.ibm.wala.ipa.cha.IClassHierarchy;
import com.ibm.wala.shrike.shrikeBT.IInvokeInstruction.Dispatch;
import com.ibm.wala.ssa.SSANewInstruction;
import com.ibm.wala.types.FieldReference;
import com.ibm.wala.types.MethodReference;
import com.ibm.wala.types.TypeReference;
import com.ibm.wala.util.collections.HashMapFactory;
import com.ibm.wala.util.collections.Pair;

public class LinkedEntrypoint extends DefaultEntrypoint {

	private final Map<Pair<List<Either<Atom, Integer>>, TypeReference>, TypeReference> linkage;
	private final IClass selfType;
	
	public LinkedEntrypoint(IMethod method, IClassHierarchy cha, IClass selfType, Map<Pair<List<Either<Atom, Integer>>, TypeReference>, TypeReference> map) {
		super(method, cha);
		this.linkage = map;
		this.selfType = selfType;
	}

	public LinkedEntrypoint(MethodReference method, IClassHierarchy cha,IClass selfType,  Map<Pair<List<Either<Atom, Integer>>, TypeReference>, TypeReference> linkage) {
		super(method, cha);
		this.linkage = linkage;
		this.selfType = selfType;
	}

	@Override
	protected int makeArgument(AbstractRootMethod m, int i) {
		TypeReference r = this.method.getParameterType(i);
		if (r != SolidityTypes.address && !(r.isReferenceType() && getCha().lookupClass(r).isInterface())) {
			int vn = super.makeArgument(m, i);
			if (i == 0) {
				int self = selfForType(selfType, m);
				m.addSetInstance(getCha().resolveField(FieldReference.findOrCreate(SolidityTypes.root, Atom.findOrCreateUnicodeAtom("self"), SolidityTypes.root)).getReference(), vn, self);
			}
			return vn;
		} else {
			return m.addInvocation(new int[0], CallSiteReference.make(i, MethodReference.findOrCreate(SolidityAddressInstantiator.aiRef, SolidityAddressInstantiator.aiSel), Dispatch.STATIC)).getDef();
		}
	}

	static Map<TypeReference,Integer> selfMap = HashMapFactory.make();
	
	private int selfForType(IClass selfType, AbstractRootMethod m) {
		if (selfMap.containsKey(selfType.getReference())) {
			return selfMap.get(selfType.getReference());
		} else {
			int objSelf = m.addAllocation(selfType.getReference()).getDef();
			for(IField f : selfType.getAllInstanceFields()) {
				if (f.getFieldTypeReference().isArrayType()) {
					SSANewInstruction alloc = m.addArrayAllocation(f.getFieldTypeReference());
					m.addSetInstance(f.getReference(), objSelf, alloc.getDef());
				}
			}
			linkage.forEach((x, y) -> { 
				if (selfType.getReference().equals(x.snd)) {
					int o = objSelf;
					TypeReference t = selfType.getReference();
					Iterator<Either<Atom, Integer>> path = x.fst.iterator();
					while (path.hasNext()) {
						Either<Atom, Integer> elt = path.next();
						boolean last = !path.hasNext();
						if (elt.isLeft()) {
							IField f = getCha().lookupClass(t).getField(elt.getLeft());					
							if (last) {
								SSANewInstruction alloc = m.addAllocation(y);
								m.addSetInstance(f.getReference(), o, alloc.getDef());
							} else {
								o = m.addGetInstance(f.getReference(), o);
								t = f.getFieldTypeReference();
							}
						} else {
							TypeReference eltType = getCha().lookupClass(t).getReference().getArrayElementType();
							int index = elt.getRight();
							if (last) {
								SSANewInstruction alloc = m.addAllocation(y);
								m.addSetArrayField(y, o, m.getValueNumberForIntConstant(index), alloc.getDef());
							} else {
								m.addGetArrayField(eltType, o, index);
								t = eltType;
							}	
						}
					}
				}
			});
			selfMap.put(selfType.getReference(), objSelf);
			return objSelf;
		}
	}
		
	@Override
	public TypeReference[] getParameterTypes(int i) {
		return new TypeReference[] { method.getParameterType(i) };
	}

	public static List<Entrypoint> getContractEntrypoints(CVLLinkageSpec spec, IClassHierarchy cha) {
		return getContractEntrypoints(spec.getLink(), cha);
	}
	
	public static List<Entrypoint> getContractEntrypoints(Map<Pair<List<Either<Atom, Integer>>, TypeReference>, TypeReference> map, IClassHierarchy cha) {
		List<Entrypoint> es = new ArrayList<>();
		IClass contractClass = cha.lookupClass(SolidityTypes.contract);
		cha.forEach(cls -> { 
			if (cls != contractClass && cha.isAssignableFrom(contractClass, cls) && !cls.isInterface() && !cls.isAbstract()) {
				allSupersIncludingSelf(cls).forEach(x ->
				x.getDeclaredInstanceFields().forEach(m -> { 
					IClass fieldClass = cha.lookupClass(TypeReference.findOrCreate(SolidityTypes.solidity, m.getName().toString()));
					if (fieldClass != null && !m.getDeclaringClass().isInterface() && cha.isSubclassOf(fieldClass, cha.lookupClass(SolidityTypes.function))) {
						AstFunctionClass afc = (AstFunctionClass) fieldClass;
						if (afc.isPublic() && !afc.isAbstract() && afc.getCodeBody() != null) {
							es.add(new LinkedEntrypoint(afc.getCodeBody(), cha, cls, map));
						}
					}
				}));
			}
		});
		return es;
	}
}
