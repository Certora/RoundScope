package com.certora.wala.cast.solidity.loader;

import java.io.File;
import java.util.Collections;
import java.util.Set;

import com.ibm.wala.cast.ipa.callgraph.CAstAnalysisScope;
import com.ibm.wala.cast.ir.ssa.AstIRFactory;
import com.ibm.wala.cast.loader.SingleClassLoaderFactory;
import com.ibm.wala.classLoader.IMethod;
import com.ibm.wala.classLoader.Module;
import com.ibm.wala.classLoader.SourceFileModule;
import com.ibm.wala.ipa.callgraph.AnalysisScope;
import com.ibm.wala.ipa.callgraph.impl.Everywhere;
import com.ibm.wala.ipa.cha.ClassHierarchyException;
import com.ibm.wala.ipa.cha.ClassHierarchyFactory;
import com.ibm.wala.ipa.cha.IClassHierarchy;
import com.ibm.wala.ssa.IRFactory;
import com.ibm.wala.ssa.SSAOptions;
import com.ibm.wala.util.collections.HashSetFactory;

public class TestRunner {

	public static void main(String[] args) throws ClassHierarchyException {
		Set<Module> files = HashSetFactory.make();
		for(String f : args) {
			files.add(new SourceFileModule(new File(f), f, null));
		}
		
		SingleClassLoaderFactory sl = new SolidityLoaderFactory();
		
		AnalysisScope s = new CAstAnalysisScope(files.toArray(new Module[files.size()]), sl, Collections.singleton(SolidityLoader.solidity));

		IClassHierarchy cha = ClassHierarchyFactory.make(s, sl);
		
		System.out.println(cha);
		IRFactory<IMethod> f = AstIRFactory.makeDefaultFactory();
		cha.forEach(c -> { 
			c.getDeclaredMethods().forEach(m -> { 
				System.out.println(f.makeIR(m, Everywhere.EVERYWHERE, SSAOptions.defaultOptions()));
			});
		});
	}

}
