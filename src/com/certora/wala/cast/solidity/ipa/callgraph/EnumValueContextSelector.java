package com.certora.wala.cast.solidity.ipa.callgraph;

import java.util.Map;

import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.ibm.wala.classLoader.CallSiteReference;
import com.ibm.wala.classLoader.IClass;
import com.ibm.wala.classLoader.IMethod;
import com.ibm.wala.ipa.callgraph.CGNode;
import com.ibm.wala.ipa.callgraph.Context;
import com.ibm.wala.ipa.callgraph.ContextKey;
import com.ibm.wala.ipa.callgraph.ContextSelector;
import com.ibm.wala.ipa.callgraph.propagation.InstanceKey;
import com.ibm.wala.ipa.callgraph.propagation.SelectiveCPAContext;
import com.ibm.wala.ipa.cha.IClassHierarchy;
import com.ibm.wala.util.collections.HashMapFactory;
import com.ibm.wala.util.intset.IntSet;
import com.ibm.wala.util.intset.IntSetAction;
import com.ibm.wala.util.intset.IntSetUtil;
import com.ibm.wala.util.intset.MutableIntSet;

public class EnumValueContextSelector implements ContextSelector {

	private final ContextSelector base;

	public EnumValueContextSelector(ContextSelector base) {
		this.base = base;
	}
	
	@Override
	public Context getCalleeTarget(CGNode caller, CallSiteReference site, IMethod callee,
			InstanceKey[] actualParameters) {
		IntSet ps = getRelevantParameters(caller, site);
		Context bc = base.getCalleeTarget(caller, site, callee, actualParameters);
		if (ps.isEmpty()) {
			return bc;
		} else {
			Map<ContextKey, InstanceKey> params = HashMapFactory.make();
			ps.foreach(new IntSetAction() {
				private int i = 1;
				@Override
				public void act(int x) {
					params.put(ContextKey.PARAMETERS[x], actualParameters[i++]);
				} 
			});
			return new SelectiveCPAContext(bc, params);
		}
		
	}

	@Override
	public IntSet getRelevantParameters(CGNode caller, CallSiteReference site) {
		MutableIntSet interesting = IntSetUtil.makeMutableCopy(base.getRelevantParameters(caller, site));
		IClassHierarchy cha = caller.getClassHierarchy();
		IMethod target = cha.resolveMethod(site.getDeclaredTarget());
		if (target != null) {
			for(int i = 0; i < target.getNumberOfParameters(); i++) {
				IClass pt = cha.lookupClass(target.getParameterType(i));
				if (pt != null && cha.isAssignableFrom(cha.lookupClass(SolidityTypes.enm), pt)) {
					interesting.add(i);
				}
			}
		}

		return interesting;
	}

}
