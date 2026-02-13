package com.certora.wala.cast.solidity.loader;

import java.io.File;
import java.io.FileNotFoundException;
import java.util.Collections;
import java.util.Map;
import java.util.Set;

import com.certora.certoraprover.cvl.Ast;
import com.certora.wala.analysis.rounding.RoundingEstimator;
import com.certora.wala.analysis.rounding.RoundingEstimator.RoundingInference;
import com.certora.wala.cast.solidity.ipa.callgraph.LinkedEntrypoint;
import com.certora.wala.cast.solidity.util.Configuration;
import com.certora.wala.cast.solidity.util.Configuration.Conf;
import com.ibm.wala.cast.ipa.callgraph.AstContextInsensitiveSSAContextInterpreter;
import com.ibm.wala.cast.ipa.callgraph.CAstAnalysisScope;
import com.ibm.wala.cast.ir.ssa.AstIRFactory;
import com.ibm.wala.cast.loader.SingleClassLoaderFactory;
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
import com.ibm.wala.ssa.IRFactory;
import com.ibm.wala.ssa.SSAOptions;
import com.ibm.wala.util.CancelException;
import com.ibm.wala.util.collections.HashMapFactory;

public class TestRunner {

	public static void main(String[] args) throws ClassHierarchyException, FileNotFoundException,
			IllegalArgumentException, CallGraphBuilderCancelException {
		try {
			File confFile = new File(args[0]);
			Conf conf = Configuration.getConf(confFile);
			try {
				getSpecRules(conf);
			} catch (IllegalStateException e) {

			}

			SingleClassLoaderFactory sl = new SolidityLoaderFactory(confFile, conf.getIncludePath());

			AnalysisScope s = new CAstAnalysisScope(conf.getFiles().toArray(new Module[conf.getFiles().size()]), sl,
					Collections.singleton(SolidityLoader.solidity));

			IClassHierarchy cha = ClassHierarchyFactory.make(s, sl);

			System.out.println(cha);

			Set<Entrypoint> es = LinkedEntrypoint.getContractEntrypoints(conf.getLink(), cha);

			System.out.println("Entrypoints:");
			es.forEach(e -> System.out.println(e));
			System.out.println();

			IRFactory<IMethod> f = AstIRFactory.makeDefaultFactory();
			cha.forEach(c -> {
				c.getDeclaredMethods().forEach(m -> {
					try {
						System.out.println(f.makeIR(m, Everywhere.EVERYWHERE, SSAOptions.defaultOptions()));
					} catch (RuntimeException e) {
						System.err.println(e);
					}
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
			SSAPropagationCallGraphBuilder cgBuilder = new nCFABuilder(2,
					SolidityLoader.solidity.getFakeRootMethod(cha, options, analysisCache), options, analysisCache,
					appSelector, appInterpreter);
			cgBuilder.setContextInterpreter(new AstContextInsensitiveSSAContextInterpreter(options, analysisCache));

			CallGraph cg = cgBuilder.makeCallGraph(options, null);

			SDG<InstanceKey> sdg = new SDG<>(cg, cgBuilder.getPointerAnalysis(),
					Slicer.DataDependenceOptions.NO_BASE_NO_HEAP, Slicer.ControlDependenceOptions.NO_EXCEPTIONAL_EDGES);

			System.out.println(sdg);
			System.out.println(cg);

			Map<CGNode, RoundingEstimator.Direction> rounding = HashMapFactory.make();
			boolean changed;
			do {
				changed = false;
				for (CGNode n : cg) {
					RoundingEstimator re = new RoundingEstimator(n);
					RoundingEstimator.Direction d = re.analyze(cg, rounding);
					if (rounding.put(n, d) != d) {
						changed = true;
					}
				}
			} while (changed);

			rounding.entrySet().forEach(x -> {
				if (x.getValue() != RoundingEstimator.Direction.Neither) {
					System.err.println(x.getKey().getMethod().getDeclaringClass().getName() + " --> " + x.getValue());
				}
			});
			
			rounding = HashMapFactory.make();
			do {
				changed = false;
				for (CGNode n : cg) {
					RoundingInference ri = new RoundingEstimator(n).new RoundingInference(cg, rounding, n);
					RoundingEstimator.Direction d = ri.getResult();
					System.err.println(n + "\n" + ri);
					if (rounding.put(n, d) != d) {
						changed = true;
					}
				}
			} while (changed);

 			rounding.entrySet().forEach(x -> {
				if (x.getValue() != RoundingEstimator.Direction.Neither) {
					System.err.println(x.getKey().getMethod().getDeclaringClass().getName() + " --> " + x.getValue());
				}
			});
			
		} catch (RuntimeException | CancelException e) {
			assert false : e;
		}
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
