package com.certora.wala.cast.solidity.loader;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileWriter;
import java.io.IOException;
import java.util.Collections;
import java.util.Map;
import java.util.Set;

import org.json.JSONArray;

import com.certora.certoraprover.cvl.Ast;
import com.certora.wala.analysis.rounding.Direction;
import com.certora.wala.analysis.rounding.RoundingAnalysis;
import com.certora.wala.analysis.rounding.RoundingAnalysis.RoundingInference.Result;
import com.certora.wala.analysis.rounding.RoundingEstimator;
import com.certora.wala.cast.solidity.ipa.callgraph.LinkedEntrypoint;
import com.certora.wala.cast.solidity.ipa.callgraph.SolidityAddressInstantiator;
import com.certora.wala.cast.solidity.ipa.callgraph.VirtualTargetSelector;
import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.certora.wala.cast.solidity.util.Configuration;
import com.certora.wala.cast.solidity.util.Configuration.Conf;
import com.certora.wala.cast.solidity.util.JSONOutput;
import com.ibm.wala.analysis.reflection.FactoryBypassInterpreter;
import com.ibm.wala.cast.ipa.callgraph.AstContextInsensitiveSSAContextInterpreter;
import com.ibm.wala.cast.ipa.callgraph.CAstAnalysisScope;
import com.ibm.wala.cast.ipa.callgraph.CAstCallGraphUtil;
import com.ibm.wala.cast.ir.ssa.AstIRFactory;
import com.ibm.wala.cast.loader.AstClass;
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
import com.ibm.wala.ipa.callgraph.propagation.PointerAnalysis;
import com.ibm.wala.ipa.callgraph.propagation.SSAContextInterpreter;
import com.ibm.wala.ipa.callgraph.propagation.SSAPropagationCallGraphBuilder;
import com.ibm.wala.ipa.callgraph.propagation.cfa.DelegatingSSAContextInterpreter;
import com.ibm.wala.ipa.callgraph.propagation.cfa.ZeroXInstanceKeys;
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

	private static boolean useOldAnalysis = false;

	public static void main(String[] args) throws ClassHierarchyException, FileNotFoundException,
			IllegalArgumentException, CallGraphBuilderCancelException {
		try {
			File confFile = new File(args[0]);
			Conf conf = Configuration.getConf(confFile);
			try {
				getSpecRules(conf);
			} catch (Exception | Error e) {

			}

			SingleClassLoaderFactory sl = new SolidityLoaderFactory(confFile, conf.getIncludePath());

			AnalysisScope s = new CAstAnalysisScope(conf.getFiles().toArray(new Module[conf.getFiles().size()]), sl,
					Collections.singleton(SolidityLoader.solidity));

			System.out.println(s);

			IClassHierarchy cha = ClassHierarchyFactory.make(s, sl);

			new SolidityAddressInstantiator(cha);
			
			SolidityLoader solidityLoader = (SolidityLoader) cha.getLoader(SolidityTypes.solidity);
			solidityLoader.getModulesWithParseErrors().forEachRemaining(m -> {
				solidityLoader.getMessages(m).forEach(msg -> {
					System.err.println(msg);
				});
			});

			solidityLoader.getModulesWithWarnings().forEachRemaining(m -> {
				solidityLoader.getMessages(m).forEach(msg -> {
					System.err.println(msg);
				});
			});

			System.out.println(cha);

			Set<Entrypoint> es = LinkedEntrypoint.getContractEntrypoints(conf.getLink(), cha);

			System.out.println("Entrypoints:");
			es.forEach(e -> System.out.println(e));
			System.out.println();

			IRFactory<IMethod> f = AstIRFactory.makeDefaultFactory();
			cha.forEach(c -> {
				if (c instanceof AstClass) {
				c.getDeclaredMethods().forEach(m -> {
					try {
						System.out.println(f.makeIR(m, Everywhere.EVERYWHERE, SSAOptions.defaultOptions()));
					} catch (RuntimeException e) {
						System.err.println(e);
					}
				});
				}
			});

			Util.setNativeSpec(null);
			AnalysisOptions options = new AnalysisOptions();
			AnalysisCache analysisCache = new AnalysisCacheImpl(f);
			options.setEntrypoints(es);

			Util.addDefaultSelectors(options, cha);
			Util.addDefaultBypassLogic(options, Util.class.getClassLoader(), cha);
					ContextSelector appSelector = null;
			SSAContextInterpreter appInterpreter = null;
			SSAPropagationCallGraphBuilder cgBuilder = new nCFABuilder(2,
					SolidityLoader.solidity.getFakeRootMethod(cha, options, analysisCache), options, analysisCache,
					appSelector, appInterpreter);
		
			options.setSelector(new VirtualTargetSelector(cgBuilder, options));

			cgBuilder.setContextInterpreter(
				new DelegatingSSAContextInterpreter(
		              new FactoryBypassInterpreter(options, analysisCache), 
		              new AstContextInsensitiveSSAContextInterpreter(options, analysisCache)));

			cgBuilder.setInstanceKeys(new ZeroXInstanceKeys(options, cha, cgBuilder.getContextInterpreter(), ZeroXInstanceKeys.ALLOCATIONS));
			
			CallGraph cg = cgBuilder.makeCallGraph(options, null);

			PointerAnalysis<InstanceKey> PA = cgBuilder.getPointerAnalysis();
			SDG<InstanceKey> sdg = new SDG<>(cg, PA, Slicer.DataDependenceOptions.NO_BASE_NO_HEAP,
					Slicer.ControlDependenceOptions.NO_EXCEPTIONAL_EDGES);

			System.out.println(sdg);

			CAstCallGraphUtil.AVOID_DUMP.set(false);
			CAstCallGraphUtil.dumpCG(cgBuilder.getCFAContextInterpreter(), PA, cg);
			
			boolean changed;
			if (useOldAnalysis) {
				Map<CGNode, Direction> rounding = HashMapFactory.make();
				do {
					changed = false;
					for (CGNode n : cg) {
						RoundingEstimator re = new RoundingEstimator(n);
						Direction d = re.analyze(cg, rounding);
						if (rounding.put(n, d) != d) {
							changed = true;
						}
					}
				} while (changed);

				rounding.entrySet().forEach(x -> {
					if (x.getValue() != Direction.Neither) {
						System.err
								.println(x.getKey().getMethod().getDeclaringClass().getName() + " --> " + x.getValue());
					}
				});
				
			} else {
				JSONArray graphs = new JSONArray();
				for(CGNode n : cg.getEntrypointNodes()) {
					
					Result G = RoundingAnalysis.analyzeForNode(cg, n);

				    graphs.put(JSONOutput.outputAsJSON(PA, n, G));

				    String res = G.toString();
				    if (res.contains("--> Up") || res.contains("--> Down") || res.contains("--> Either")) {
						System.out.println("looking at " + n + "  --> " + G.getReturnRounding());
				    	System.out.println(res);
				    }
				}
				
				try (FileWriter jo = new FileWriter(args[1])) {
					graphs.write(jo, 4, 0);
				}
			}
		} catch (RuntimeException | CancelException | IOException e) {
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
