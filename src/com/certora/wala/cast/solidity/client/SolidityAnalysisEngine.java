package com.certora.wala.cast.solidity.client;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;

import com.certora.wala.cast.solidity.ipa.callgraph.LinkedEntrypoint;
import com.certora.wala.cast.solidity.ipa.callgraph.SolidityAddressInstantiator;
import com.certora.wala.cast.solidity.ipa.callgraph.VirtualTargetSelector;
import com.certora.wala.cast.solidity.loader.SolidityLoader;
import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.certora.wala.cast.solidity.util.Configuration;
import com.certora.wala.cast.solidity.util.Configuration.Conf;
import com.ibm.wala.analysis.reflection.FactoryBypassInterpreter;
import com.ibm.wala.cast.ipa.callgraph.AstContextInsensitiveSSAContextInterpreter;
import com.ibm.wala.cast.ir.ssa.AstIRFactory;
import com.ibm.wala.cast.loader.SingleClassLoaderFactory;
import com.ibm.wala.client.AbstractAnalysisEngine;
import com.ibm.wala.ipa.callgraph.AnalysisCacheImpl;
import com.ibm.wala.ipa.callgraph.AnalysisOptions;
import com.ibm.wala.ipa.callgraph.CallGraphBuilder;
import com.ibm.wala.ipa.callgraph.ContextSelector;
import com.ibm.wala.ipa.callgraph.Entrypoint;
import com.ibm.wala.ipa.callgraph.IAnalysisCacheView;
import com.ibm.wala.ipa.callgraph.impl.Util;
import com.ibm.wala.ipa.callgraph.propagation.InstanceKey;
import com.ibm.wala.ipa.callgraph.propagation.PropagationCallGraphBuilder;
import com.ibm.wala.ipa.callgraph.propagation.SSAContextInterpreter;
import com.ibm.wala.ipa.callgraph.propagation.SSAPropagationCallGraphBuilder;
import com.ibm.wala.ipa.callgraph.propagation.cfa.DelegatingSSAContextInterpreter;
import com.ibm.wala.ipa.callgraph.propagation.cfa.ZeroXInstanceKeys;
import com.ibm.wala.ipa.callgraph.propagation.cfa.nCFABuilder;
import com.ibm.wala.ipa.cha.ClassHierarchyException;
import com.ibm.wala.ipa.cha.ClassHierarchyFactory;
import com.ibm.wala.ipa.cha.IClassHierarchy;
import com.ibm.wala.ssa.SSAOptions.DefaultValues;
import com.ibm.wala.ssa.SymbolTable;

public abstract class SolidityAnalysisEngine<A> extends AbstractAnalysisEngine<InstanceKey, CallGraphBuilder<InstanceKey>, A> {

	protected final File confFile;
	protected final Conf conf;
	protected SingleClassLoaderFactory loaders;
	
	protected SolidityAnalysisEngine(File confFile) throws FileNotFoundException {
		this.confFile = confFile;
		this.conf = Configuration.getConf(confFile);
	}
	
	@Override
	protected PropagationCallGraphBuilder getCallGraphBuilder(IClassHierarchy cha, AnalysisOptions options,
			IAnalysisCacheView analysisCache) {
		
		new SolidityAddressInstantiator(cha);
		
		Util.setNativeSpec(null);
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

		return cgBuilder;
	}

	@Override
	public IClassHierarchy buildClassHierarchy() {
		IClassHierarchy cha;
		try {
			cha = ClassHierarchyFactory.make(scope, loaders);
			setClassHierarchy(cha);
			
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

			return cha;
		} catch (ClassHierarchyException e) {
			assert false : e;
			return null;
		}
	}

	private AnalysisOptions makeOptions() {
		AnalysisOptions options = new AnalysisOptions();
		options.getSSAOptions().setDefaultValues(new DefaultValues() {

			@Override
			public int getDefaultValue(SymbolTable symtab, int valueNumber) {
				return symtab.getConstant(0);
			} 
			
		});
		return options;
		
	}
	
	  @Override
	  public IAnalysisCacheView makeDefaultCache() {
	    return new AnalysisCacheImpl(AstIRFactory.makeDefaultFactory(), makeOptions().getSSAOptions());
	  }

	@Override
	protected Iterable<Entrypoint> makeDefaultEntrypoints(IClassHierarchy cha) {
		return LinkedEntrypoint.getContractEntrypoints(conf.getLink(), cha);
	}

	@Override
	public AnalysisOptions getDefaultOptions(Iterable<Entrypoint> entrypoints) {
		AnalysisOptions options = makeOptions();
		options.setEntrypoints(entrypoints);
		return options;
	}

	@Override
	public PropagationCallGraphBuilder defaultCallGraphBuilder() throws IllegalArgumentException, IOException {
		return getCallGraphBuilder(
				getClassHierarchy(), 
				getDefaultOptions(makeDefaultEntrypoints(getClassHierarchy())),
				makeDefaultCache());
	}

}
