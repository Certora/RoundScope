package com.certora.wala.cast.solidity.client;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.Map;

import com.certora.wala.cast.solidity.ipa.callgraph.EnumValueContextSelector;
import com.certora.wala.cast.solidity.ipa.callgraph.LinkedEntrypoint;
import com.certora.wala.cast.solidity.ipa.callgraph.SolidityAddressInstantiator;
import com.certora.wala.cast.solidity.ipa.callgraph.VirtualTargetSelector;
import com.certora.wala.cast.solidity.loader.EnumType;
import com.certora.wala.cast.solidity.loader.SolidityLoader;
import com.certora.wala.cast.solidity.translator.InterproceduralConstantFoldingRewriter;
import com.certora.wala.cast.solidity.translator.SolidityAstTranslator;
import com.certora.wala.cast.solidity.tree.SolidityCAstType;
import com.certora.wala.cast.solidity.types.SolidityTypes;
import com.certora.wala.cast.solidity.util.Configuration;
import com.certora.wala.cast.solidity.util.Configuration.Conf;
import com.ibm.wala.analysis.reflection.FactoryBypassInterpreter;
import com.ibm.wala.cast.ipa.callgraph.AstContextInsensitiveSSAContextInterpreter;
import com.ibm.wala.cast.ir.ssa.AstIRFactory;
import com.ibm.wala.cast.ir.ssa.AstIRFactory.AstDefaultIRFactory;
import com.ibm.wala.cast.ir.translator.AstTranslator;
import com.ibm.wala.cast.loader.AstMethod.Retranslatable;
import com.ibm.wala.cast.loader.SingleClassLoaderFactory;
import com.ibm.wala.cast.tree.CAst;
import com.ibm.wala.cast.tree.CAstControlFlowMap;
import com.ibm.wala.cast.tree.CAstEntity;
import com.ibm.wala.cast.tree.CAstNode;
import com.ibm.wala.cast.tree.CAstType;
import com.ibm.wala.cast.tree.impl.CAstImpl;
import com.ibm.wala.cast.tree.impl.CAstOperator;
import com.ibm.wala.cfg.ControlFlowGraph;
import com.ibm.wala.classLoader.IClass;
import com.ibm.wala.classLoader.IMethod;
import com.ibm.wala.client.AbstractAnalysisEngine;
import com.ibm.wala.ipa.callgraph.AnalysisCacheImpl;
import com.ibm.wala.ipa.callgraph.AnalysisOptions;
import com.ibm.wala.ipa.callgraph.CGNode;
import com.ibm.wala.ipa.callgraph.CallGraphBuilder;
import com.ibm.wala.ipa.callgraph.Context;
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
import com.ibm.wala.ssa.DefUse;
import com.ibm.wala.ssa.IR;
import com.ibm.wala.ssa.IRView;
import com.ibm.wala.ssa.ISSABasicBlock;
import com.ibm.wala.ssa.SSAInstruction;
import com.ibm.wala.ssa.SSAOptions;
import com.ibm.wala.ssa.SSAOptions.DefaultValues;
import com.ibm.wala.ssa.SymbolTable;
import com.ibm.wala.types.TypeName;
import com.ibm.wala.types.TypeReference;
import com.ibm.wala.util.CancelException;
import com.ibm.wala.util.MonitorUtil.IProgressMonitor;
import com.ibm.wala.util.WalaRuntimeException;
import com.ibm.wala.util.collections.HashMapFactory;
import com.ibm.wala.util.collections.Pair;

public abstract class SolidityAnalysisEngine<A> extends AbstractAnalysisEngine<InstanceKey, CallGraphBuilder<InstanceKey>, A> {

	public final Map<String, Long> statistics = HashMapFactory.make();
	
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
	              new AstContextInsensitiveSSAContextInterpreter(options, analysisCache) {

					@Override
					public IR getIR(CGNode node) {
					    return getAnalysisCache().getIR(node.getMethod(), node.getContext());
					}

					@Override
					public IRView getIRView(CGNode node) {
						return getIR(node);
					}

					@Override
					public ControlFlowGraph<SSAInstruction, ISSABasicBlock> getCFG(CGNode N) {
						return getIR(N).getControlFlowGraph();
					}

					@Override
					public DefUse getDU(CGNode node) {
						return new DefUse(getIR(node));
					}
	            	  
	              }));

		cgBuilder.setInstanceKeys(new ZeroXInstanceKeys(options, cha, cgBuilder.getContextInterpreter(), ZeroXInstanceKeys.ALLOCATIONS));

		cgBuilder.setContextSelector(new EnumValueContextSelector(cgBuilder.getContextSelector()));
		
		return cgBuilder;
	}

	@Override
	public IClassHierarchy buildClassHierarchy() {
		long start = System.nanoTime();
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
			throw new WalaRuntimeException("failed to create class hierarchy", e);
		} finally {
			statistics.put("build_cha", System.nanoTime() - start);
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
		
		options.setUseConstantSpecificKeys(true);
		
		return options;
		
	}

	public boolean checkEnumParameters(IMethod target) {
		for(int i = 0; i < target.getNumberOfParameters(); i++) {
			IClass pt = getClassHierarchy().lookupClass(target.getParameterType(i));
			if (pt != null && getClassHierarchy().isAssignableFrom(getClassHierarchy().lookupClass(SolidityTypes.enm), pt)) {
				return true;
			}
		}

		return false;
	}

	private boolean shouldRetranslate(IMethod method, Context context) {
		return checkEnumParameters(method);
	}
	

	  @Override
	  public IAnalysisCacheView makeDefaultCache() {
	    return new AnalysisCacheImpl(new AstDefaultIRFactory<IMethod>(new AstIRFactory<IMethod>() {
			@Override
			public boolean contextIsIrrelevant(IMethod method) {
				return !checkEnumParameters(method);
			}
				    	
	    }) {
			@Override
			public boolean contextIsIrrelevant(IMethod target) {
				return !checkEnumParameters(target);
			}

			@Override
			public ControlFlowGraph<?, ?> makeCFG(IMethod method, Context context) {
				if (shouldRetranslate(method, context)) {
					return super.makeCFG(method, context);					
				} else {
					return super.makeCFG(method, context);
				}
			}
			
			class SolidityEnumConstantRewriter extends InterproceduralConstantFoldingRewriter {

				public SolidityEnumConstantRewriter(CAstEntity fun, Context context, CAst Ast) {
					super(fun, context, Ast);
				}

				
				@Override
				protected CAstNode copyNodes(CAstNode root, CAstControlFlowMap cfg, NonCopyingContext context,
						Map<Pair<CAstNode, NoKey>, CAstNode> nodeMap) {
					CAstNode newRoot = super.copyNodes(root, cfg, context, nodeMap);
					
					if (newRoot.getKind() == CAstNode.BINARY_EXPR && 
						newRoot.getChild(1).getKind() == CAstNode.CONSTANT &&
						newRoot.getChild(2).getKind() == CAstNode.CONSTANT) {
						Object left = newRoot.getChild(1).getValue();
						Object right = newRoot.getChild(2).getValue();
						boolean numeric = left instanceof Number && right instanceof Number;
						CAstNode result = null;
						if (newRoot.getChild(0).equals(CAstOperator.OP_EQ)) {
							result = Ast.makeConstant(left.equals(right));
						} else if (newRoot.getChild(0).equals(CAstOperator.OP_NE)) {
							result = Ast.makeConstant(! left.equals(right));
						} else if (numeric && newRoot.getChild(0).equals(CAstOperator.OP_MOD)) {
							result = Ast.makeConstant(((Number)left).intValue() % ((Number)right).intValue());
						}
						
					    if (result != null) {
					    	nodeMap.put(Pair.make(root, context.key()), result);
					    	return result;
					    }
						
					} else if (newRoot.getKind() == CAstNode.BINARY_EXPR && newRoot.getChild(0).equals(CAstOperator.OP_EQ)) {
						CAstType lct = fun.getNodeTypeMap().getNodeType(root.getChild(1));
						TypeReference ltr = SolidityCAstType.getIRType(lct);
						IClassHierarchy cha = getClassHierarchy();
						IClass lc = cha.lookupClass(ltr);
						if (lc != null && 
							cha.isAssignableFrom(cha.lookupClass(SolidityTypes.enm), lc) 
							&& (newRoot.getChild(1).getKind() == CAstNode.CONSTANT ||
								newRoot.getChild(2).getKind() == CAstNode.CONSTANT)) {
							
							CAstNode left;
							if (newRoot.getChild(1).getKind() == CAstNode.NEW) {
								left = newRoot.getChild(1).getChild(1);
							} else {
								left = newRoot.getChild(1);
							}
							
							CAstNode right;
							if (newRoot.getChild(2).getKind() == CAstNode.NEW) {
								right = newRoot.getChild(2).getChild(1);
							} else {
								right = newRoot.getChild(2);
							}
							
							if (left.getKind() == CAstNode.CONSTANT && right.getKind() == CAstNode.CONSTANT) {
								CAstNode result = Ast.makeConstant(left.getValue().equals(right.getValue()));
							    nodeMap.put(Pair.make(root, context.key()), result);
							    return result;
							}
						}
					} else if (newRoot.getKind() == CAstNode.CALL && 
							   newRoot.getChildCount() > 2 &&
							   newRoot.getChild(0).getKind() == CAstNode.TYPE_LITERAL_EXPR &&
							   newRoot.getChild(2).getKind() == CAstNode.CONSTANT) {
						CAstType rvct = fun.getNodeTypeMap().getNodeType(root.getChild(2));
						TypeReference rvtr = SolidityCAstType.getIRType(rvct);
						IClassHierarchy cha = getClassHierarchy();
						IClass rvc = cha.lookupClass(rvtr);

						if (rvc != null && cha.isAssignableFrom(cha.lookupClass(SolidityTypes.enm), rvc)) { 
							int idx;
							if ((idx = ((EnumType)rvct).getMembers().indexOf(newRoot.getChild(2).getValue())) >= 0) {
								CAstNode result = Ast.makeConstant(idx);
							    nodeMap.put(Pair.make(root, context.key()), result);
							    return result;		
							}
						}
					}
					
					return newRoot;
				}


				@Override
				protected Object eval(CAstOperator op, Object lhs, Object rhs) {
					// TODO Auto-generated method stub
					return null;
				}
				
			};
			
			@Override
			public IR makeIR(IMethod method, final Context context, final SSAOptions options) {
				  if (shouldRetranslate(method, context)) {
					  SolidityLoader loader = (SolidityLoader)loaders.getTheLoader();
					  loader.startRetranslating();
					  
					  AstTranslator xlator = new SolidityAstTranslator(loader) {
						  @Override
						  public void translate(CAstEntity N, final WalkContext walkContext) {
							  N = new SolidityEnumConstantRewriter(N, context, new CAstImpl()).rewrite(N);
							  super.translate(N, walkContext);
						  }
					  };

					  ((Retranslatable)method).retranslate(xlator);
					  
					  Map<TypeName, IClass> x = loader.doneRetranslating();
					  method = x.get(method.getDeclaringClass().getName()).getMethod(method.getSelector());
				  }

				  
				  return super.makeIR(method, context, options);
			  }

	    }, makeOptions().getSSAOptions());
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
	protected CallGraphBuilder<InstanceKey> buildCallGraph(IClassHierarchy cha, AnalysisOptions options,
			boolean savePointerAnalysis, IProgressMonitor monitor) throws IllegalArgumentException, CancelException {
		long start = System.nanoTime();
		try {
			return super.buildCallGraph(cha, options, savePointerAnalysis, monitor);
		} finally {
			statistics.put("build_cg", System.nanoTime() - start);			
		}
	}

	@Override
	public PropagationCallGraphBuilder defaultCallGraphBuilder() throws IllegalArgumentException, IOException {
		return getCallGraphBuilder(
				getClassHierarchy(), 
				getDefaultOptions(makeDefaultEntrypoints(getClassHierarchy())),
				makeDefaultCache());
	}

}
