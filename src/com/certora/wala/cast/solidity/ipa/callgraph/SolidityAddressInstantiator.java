package com.certora.wala.cast.solidity.ipa.callgraph;

import java.util.Collection;
import java.util.Collections;

import com.certora.wala.cast.solidity.loader.SolidityLoader;
import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.ibm.wala.classLoader.IClass;
import com.ibm.wala.classLoader.IField;
import com.ibm.wala.classLoader.IMethod;
import com.ibm.wala.classLoader.NewSiteReference;
import com.ibm.wala.classLoader.SyntheticClass;
import com.ibm.wala.core.util.strings.Atom;
import com.ibm.wala.ipa.cha.IClassHierarchy;
import com.ibm.wala.ipa.summaries.MethodSummary;
import com.ibm.wala.ipa.summaries.SummarizedMethod;
import com.ibm.wala.ssa.SSAInstructionFactory;
import com.ibm.wala.types.MethodReference;
import com.ibm.wala.types.Selector;
import com.ibm.wala.types.TypeReference;

public class SolidityAddressInstantiator {
	public static final Selector aiSel = Selector.make("addressInstantiator()Loot;");
	
	public static final TypeReference aiRef = TypeReference.findOrCreate(SolidityTypes.solidity, "AddressInstantiator");

	private final SyntheticClass ai;
	
	public SolidityAddressInstantiator(IClassHierarchy cha) {		
		ai = new SyntheticClass(aiRef, cha) {

			private final IMethod addressInstantiator;
			
			{
				SSAInstructionFactory insts = SolidityLoader.solidity.instructionFactory();
				MethodReference ref = MethodReference.findOrCreate(aiRef, aiSel);
				MethodSummary m = new MethodSummary(ref);
				m.addStatement(insts.NewInstruction(0, 1, NewSiteReference.make(0, SolidityTypes.address)));
				m.addStatement(insts.ReturnInstruction(1, 1, false));
				m.setFactory(true);
				m.setStatic(true);
				addressInstantiator = new SummarizedMethod(ref, m, this);
			}				
		
			
			@Override
			public boolean isPublic() {
				return true;
			}

			@Override
			public boolean isPrivate() {
				return false;
			}

			@Override
			public int getModifiers() throws UnsupportedOperationException {
				return 0;
			}

			@Override
			public IClass getSuperclass() {
				return cha.lookupClass(SolidityTypes.root);
			}

			@Override
			public Collection<? extends IClass> getDirectInterfaces() {
				return Collections.emptyList();
			}

			@Override
			public Collection<IClass> getAllImplementedInterfaces() {
				return Collections.emptyList();
			}

			@Override
			public IMethod getMethod(Selector selector) {
				if (selector.equals(aiSel)) {
					return addressInstantiator;
				} else {
					return null;
				}
			}

			@Override
			public IField getField(Atom name) {
				return null;
			}

			@Override
			public IMethod getClassInitializer() {
				return null;
			}

			@Override
			public Collection<? extends IMethod> getDeclaredMethods() {
				return Collections.singleton(addressInstantiator);
			}

			@Override
			public Collection<IField> getAllInstanceFields() {
				return Collections.emptyList();
			}

			@Override
			public Collection<IField> getAllStaticFields() {
				return Collections.emptyList();
			}

			@Override
			public Collection<IField> getAllFields() {
				return Collections.emptyList();
			}

			@Override
			public Collection<? extends IMethod> getAllMethods() {
				return Collections.singleton(addressInstantiator);
			}

			@Override
			public Collection<IField> getDeclaredInstanceFields() {
				return Collections.emptyList();
			}

			@Override
			public Collection<IField> getDeclaredStaticFields() {
				return Collections.emptyList();
			}

			@Override
			public boolean isReferenceType() {
				return true;
			}
		};
		
		cha.addClass(ai);
	}
	
	public IMethod getFactory() {
		return ai.getMethod(aiSel);
	}

}
