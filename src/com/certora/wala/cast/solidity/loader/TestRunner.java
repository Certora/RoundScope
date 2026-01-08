package com.certora.wala.cast.solidity.loader;

import java.io.File;
import java.io.FileNotFoundException;
import java.util.Collection;
import java.util.Collections;

import com.certora.wala.cast.solidity.util.Configuration;
import com.ibm.wala.cast.ipa.callgraph.CAstAnalysisScope;
import com.ibm.wala.cast.ir.ssa.AstIRFactory;
import com.ibm.wala.cast.loader.SingleClassLoaderFactory;
import com.ibm.wala.classLoader.IMethod;
import com.ibm.wala.classLoader.Module;
import com.ibm.wala.ipa.callgraph.AnalysisScope;
import com.ibm.wala.ipa.callgraph.impl.Everywhere;
import com.ibm.wala.ipa.cha.ClassHierarchyException;
import com.ibm.wala.ipa.cha.ClassHierarchyFactory;
import com.ibm.wala.ipa.cha.IClassHierarchy;
import com.ibm.wala.ssa.IRFactory;
import com.ibm.wala.ssa.SSAOptions;

public class TestRunner {

	public static void main(String[] args) throws ClassHierarchyException, FileNotFoundException {
		Collection<Module> files = Configuration.getFiles(new File(args[0]));
		
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
