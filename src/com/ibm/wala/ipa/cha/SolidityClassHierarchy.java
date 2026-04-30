package com.ibm.wala.ipa.cha;

import java.util.Collection;
import java.util.Map;

import com.certora.wala.cast.solidity.loader.SolidityLoader;
import com.ibm.wala.classLoader.ClassLoaderFactory;
import com.ibm.wala.classLoader.IClass;
import com.ibm.wala.classLoader.Language;
import com.ibm.wala.ipa.callgraph.AnalysisScope;
import com.ibm.wala.types.TypeReference;
import com.ibm.wala.util.MonitorUtil.IProgressMonitor;

public class SolidityClassHierarchy extends ClassHierarchy {

	public SolidityClassHierarchy(AnalysisScope scope, ClassLoaderFactory factory,
			IProgressMonitor progressMonitor, Map<TypeReference, Node> map,
			MissingSuperClassHandling superClassHandling) throws ClassHierarchyException, IllegalArgumentException {
		super(scope, factory, progressMonitor, map, superClassHandling);
		// TODO Auto-generated constructor stub
	}

	public SolidityClassHierarchy(AnalysisScope scope, ClassLoaderFactory factory, Language language,
			IProgressMonitor progressMonitor, Map<TypeReference, Node> map,
			MissingSuperClassHandling superClassHandling) throws ClassHierarchyException, IllegalArgumentException {
		super(scope, factory, language, progressMonitor, map, superClassHandling);
		// TODO Auto-generated constructor stub
	}

	public SolidityClassHierarchy(AnalysisScope scope, ClassLoaderFactory factory,
			Collection<Language> languages, IProgressMonitor progressMonitor, Map<TypeReference, Node> map,
			MissingSuperClassHandling superClassHandling) throws ClassHierarchyException, IllegalArgumentException {
		super(scope, factory, languages, progressMonitor, map, superClassHandling);
		// TODO Auto-generated constructor stub
	}

	@Override
	public boolean isSubclassOf(IClass c, IClass t) {
		if (c.getClassLoader() instanceof SolidityLoader) {
			return SolidityLoader.allSupersIncludingSelf(c).contains(t);
		} else {
			return super.isSubclassOf(c, t);
		}
	}

}
