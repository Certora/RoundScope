package com.certora.wala.cast.solidity.loader;

import java.io.File;
import java.io.FileNotFoundException;
import java.util.Collections;
import java.util.Set;

import com.certora.certoraprover.cvl.Ast;
import com.certora.wala.analysis.gvn.GlobalValueNumbers;
import com.certora.wala.cast.solidity.ipa.callgraph.LinkedEntrypoint;
import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.certora.wala.cast.solidity.util.Configuration;
import com.certora.wala.cast.solidity.util.Configuration.Conf;
import com.ibm.wala.cast.ipa.callgraph.AstContextInsensitiveSSAContextInterpreter;
import com.ibm.wala.cast.ipa.callgraph.CAstAnalysisScope;
import com.ibm.wala.cast.ir.ssa.AstIRFactory;
import com.ibm.wala.cast.loader.SingleClassLoaderFactory;
import com.ibm.wala.cast.types.AstMethodReference;
import com.ibm.wala.classLoader.IMethod;
import com.ibm.wala.classLoader.Module;
import com.ibm.wala.ipa.callgraph.AnalysisCache;
import com.ibm.wala.ipa.callgraph.AnalysisCacheImpl;
import com.ibm.wala.ipa.callgraph.AnalysisOptions;
import com.ibm.wala.ipa.callgraph.AnalysisScope;
import com.ibm.wala.ipa.callgraph.CGNode;
import com.ibm.wala.ipa.callgraph.CallGraph;
import com.ibm.wala.ipa.callgraph.CallGraphBuilderCancelException;
import com.ibm.wala.ipa.callgraph.ContextSelector;
import com.ibm.wala.ipa.callgraph.Entrypoint;
import com.ibm.wala.ipa.callgraph.impl.Everywhere;
import com.ibm.wala.ipa.callgraph.impl.Util;
import com.ibm.wala.ipa.callgraph.propagation.InstanceKey;
import com.ibm.wala.ipa.callgraph.propagation.SSAContextInterpreter;
import com.ibm.wala.ipa.callgraph.propagation.SSAPropagationCallGraphBuilder;
import com.ibm.wala.ipa.callgraph.propagation.cfa.nCFABuilder;
import com.ibm.wala.ipa.cha.ClassHierarchyException;
import com.ibm.wala.ipa.cha.ClassHierarchyFactory;
import com.ibm.wala.ipa.cha.IClassHierarchy;
import com.ibm.wala.ipa.slicer.SDG;
import com.ibm.wala.ipa.slicer.Slicer;
import com.ibm.wala.ssa.IR;
import com.ibm.wala.ssa.IRFactory;
import com.ibm.wala.ssa.SSAOptions;
import com.ibm.wala.types.MethodReference;
import com.ibm.wala.types.TypeReference;

public class TestRunner {

	public static void main(String[] args) throws ClassHierarchyException, FileNotFoundException, IllegalArgumentException, CallGraphBuilderCancelException {
		Conf conf = Configuration.getConf(new File(args[0]));
		getSpecRules(conf);
				
		SingleClassLoaderFactory sl = new SolidityLoaderFactory();
		
		AnalysisScope s = new CAstAnalysisScope(
			conf.getFiles().toArray(new Module[conf.getFiles().size()]), sl, 
			Collections.singleton(SolidityLoader.solidity));

		IClassHierarchy cha = ClassHierarchyFactory.make(s, sl);
		
		Set<Entrypoint> es = LinkedEntrypoint.getContractEntrypoints(conf.getLink(), cha);
		
		System.out.println(cha);
		
		System.out.println("Entrypoints:");
		es.forEach(e -> System.out.println(e));
		System.out.println();
		
		IRFactory<IMethod> f = AstIRFactory.makeDefaultFactory();
		cha.forEach(c -> { 
			c.getDeclaredMethods().forEach(m -> { 
				System.out.println(f.makeIR(m, Everywhere.EVERYWHERE, SSAOptions.defaultOptions()));
			});
		});
		
		Util.setNativeSpec(null);
		AnalysisOptions options = new AnalysisOptions();
		options.setEntrypoints(es);
		AnalysisCache analysisCache = new AnalysisCacheImpl(f);
	    Util.addDefaultSelectors(options, cha);
	    Util.addDefaultBypassLogic(options, Util.class.getClassLoader(), cha);
	    ContextSelector appSelector = null;
	    SSAContextInterpreter appInterpreter = null;
	    SSAPropagationCallGraphBuilder cgBuilder =
	        new nCFABuilder(
	            2,
	            SolidityLoader.solidity.getFakeRootMethod(cha, options, analysisCache),
	            options,
	            analysisCache,
	            appSelector,
	            appInterpreter);
	    cgBuilder.setContextInterpreter(new AstContextInsensitiveSSAContextInterpreter(options, analysisCache));
	    
	    CallGraph cg = cgBuilder.makeCallGraph(options, null);
	    
	    SDG<InstanceKey> sdg = new SDG<>(cg, cgBuilder.getPointerAnalysis(), Slicer.DataDependenceOptions.NO_BASE_NO_HEAP, Slicer.ControlDependenceOptions.NO_EXCEPTIONAL_EDGES);

	    System.out.println(sdg);
	    System.out.println(cg);
	    
	    /*
	    CGNode muldivdown = cg.getNodes(MethodReference.findOrCreate(TypeReference.findOrCreate(SolidityTypes.solidity, "LmulDivDown (uint256,uint256,uint256) --> uint256"), AstMethodReference.fnSelector)).iterator().next();
	    IR mddir = muldivdown.getIR();
	    System.err.println(mddir);
	    System.err.println(new GlobalValueNumbers.IRValueNumbers(mddir));
	     */
	    
	    CGNode muldivup = cg.getNodes(MethodReference.findOrCreate(TypeReference.findOrCreate(SolidityTypes.solidity, "LmulDivUp (uint256,uint256,uint256) --> uint256"), AstMethodReference.fnSelector)).iterator().next();
	    IR mduir = muldivup.getIR();
	    System.err.println(mduir);
	    System.err.println(new GlobalValueNumbers.IRValueNumbers(mduir));

	}

	private static void getSpecRules(Conf files) throws FileNotFoundException {
		Ast rules = files.getRules();
		rules.getAstBaseBlocks().component1().forEach(r -> {
			System.err.println(r.toString());
			r.component8$Shared().getCmds().forEach(c -> { 
				System.err.println("  " + c.toString());
			});
		});
	}

}
