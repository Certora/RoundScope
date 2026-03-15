package com.certora.wala.cast.solidity.json;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.io.Reader;
import java.math.BigInteger;
import java.net.MalformedURLException;
import java.net.URI;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.json.JSONTokener;

import com.certora.wala.cast.solidity.loader.ContractType;
import com.certora.wala.cast.solidity.loader.EnumType;
import com.certora.wala.cast.solidity.loader.FunctionType;
import com.certora.wala.cast.solidity.loader.InterfaceType;
import com.certora.wala.cast.solidity.loader.LibraryType;
import com.certora.wala.cast.solidity.loader.StructType;
import com.certora.wala.cast.solidity.tree.CallableEntity;
import com.certora.wala.cast.solidity.tree.ContractEntity;
import com.certora.wala.cast.solidity.tree.EventEntity;
import com.certora.wala.cast.solidity.tree.FunctionEntity;
import com.certora.wala.cast.solidity.tree.SolidityArrayType;
import com.certora.wala.cast.solidity.tree.SolidityCAstType;
import com.certora.wala.cast.solidity.tree.SolidityMappingType;
import com.certora.wala.cast.solidity.tree.SolidityTupleType;
import com.google.common.collect.Streams;
import com.ibm.wala.cast.ir.translator.AbstractEntity;
import com.ibm.wala.cast.ir.translator.AbstractFieldEntity;
import com.ibm.wala.cast.ir.translator.TranslatorToCAst;
import com.ibm.wala.cast.ir.translator.TranslatorToCAst.Error;
import com.ibm.wala.cast.tree.CAst;
import com.ibm.wala.cast.tree.CAstControlFlowMap;
import com.ibm.wala.cast.tree.CAstEntity;
import com.ibm.wala.cast.tree.CAstNode;
import com.ibm.wala.cast.tree.CAstNodeTypeMap;
import com.ibm.wala.cast.tree.CAstQualifier;
import com.ibm.wala.cast.tree.CAstSourcePositionMap;
import com.ibm.wala.cast.tree.CAstSourcePositionMap.Position;
import com.ibm.wala.cast.tree.CAstSymbol;
import com.ibm.wala.cast.tree.CAstType;
import com.ibm.wala.cast.tree.impl.CAstImpl;
import com.ibm.wala.cast.tree.impl.CAstNodeTypeMapRecorder;
import com.ibm.wala.cast.tree.impl.CAstOperator;
import com.ibm.wala.cast.tree.impl.CAstSourcePositionRecorder;
import com.ibm.wala.cast.tree.impl.CAstSymbolImpl;
import com.ibm.wala.cast.tree.rewrite.CAstRewriter.CopyKey;
import com.ibm.wala.cast.tree.rewrite.CAstRewriter.RewriteContext;
import com.ibm.wala.cast.tree.rewrite.CAstRewriterFactory;
import com.ibm.wala.cast.util.CAstPrinter;
import com.ibm.wala.classLoader.IMethod.SourcePosition;
import com.ibm.wala.util.collections.HashMapFactory;
import com.ibm.wala.util.collections.HashSetFactory;
import com.ibm.wala.util.collections.Pair;

public class JSONToCAst {
	private int idx = 0;

	private final CAst ast = new CAstImpl();
	private final Map<String, CAstType> entityTypes = HashMapFactory.make();
	private final Map<CAstType, Set<String>> supers = HashMapFactory.make();

	@SuppressWarnings("unchecked")
	private <T extends CAstType> T findOrCreateType(JSONObject typeDefinition, Function<JSONObject, T> factory) {
		String typeName = typeDefinition.has("canonicalName")? typeDefinition.getString("canonicalName"): typeDefinition.getString("name");
		if (entityTypes.containsKey(typeName)) {
			return (T) entityTypes.get(typeName);
		} else {
			T st = factory.apply(typeDefinition);
			entityTypes.put(typeName, st);
			return st;
		}
	}

	private CAstType getType(JSONObject node) {
		return new JsonNodeTypeOnlyVisitor<CAstType>() {
			@SuppressWarnings("unused")
			public CAstType visitContractDefinition(JSONObject o, Void context) {
				return findOrCreateType(o, JSONToCAst.this::newContractType);
			}
			
			@SuppressWarnings("unused")
			public CAstType visitStructDefinition(JSONObject o, Void context) {
				return findOrCreateType(o, JSONToCAst.this::newStructType);
			}
			
			@SuppressWarnings("unused")
			public CAstType visitArrayTypeName(JSONObject o, Void context) {
				return SolidityArrayType.get(getType(o.getJSONObject("baseType")));
			}

			@SuppressWarnings("unused")
			public CAstType visitMapping(JSONObject o, Void context) {
				return SolidityMappingType.get(getType(o.getJSONObject("keyType")),
						getType(o.getJSONObject("valueType")));
			}

			@SuppressWarnings("unused")
			public CAstType visitElementaryTypeName(JSONObject o, Void context) {
				return SolidityCAstType.get(o.getString("name"));
			}

			@SuppressWarnings("unused")
			public CAstType visitUserDefinedTypeName(JSONObject o, Void context) {
				return getType(ids.get(o.getInt("referencedDeclaration")));
			}
			
			@Override
			public CAstType visitNode(JSONObject o, Void context) {
				return parseTypeIdentifier(o.getJSONObject("typeDescriptions").getString("typeIdentifier"));
			}
		}.visit(node, null);
	}
	
	private CAstType[] getTypes(JSONArray ps) {
		return Streams.stream(ps.iterator()).map(p -> getType((JSONObject)p)).toArray(i -> new CAstType[i]);
	}

	private final Map<Integer, JSONObject> ids = HashMapFactory.make();

	private FunctionType newFunctionType(JSONObject functionDefinition) {
		String name = functionDefinition.getString("name");
		
		CAstType selfType = null;
		if (functionDefinition.has("scope")) {
		JSONObject contract = ids.get(functionDefinition.getInt("scope"));
		if (contract != null) {
			selfType = findOrCreateType(contract, JSONToCAst.this::newContractType);
		}
		}
		
	    CAstType[] parameters = getTypes(functionDefinition.getJSONObject("parameters").getJSONArray("parameters"));
	    CAstType[] returnParameters = functionDefinition.has("returnParameters")?
	    		getTypes(functionDefinition.getJSONObject("returnParameters").getJSONArray("parameters")):
	    		null;
	
	    return FunctionType.findOrCreate(name, selfType, returnParameters, parameters);
	}

	private StructType newStructType(JSONObject structDefinition) {
		return new StructType("struct " + structDefinition.getString("canonicalName"));
	}

	private CAstType.Class newContractType(JSONObject contractDefinition) {
		String kind = contractDefinition.getString("contractKind");
		Set<String> superTypes = HashSetFactory.make();
		String name = "contract " + contractDefinition.getString("canonicalName");
		switch (kind) {
		case "interface":
			 CAstType.Class t = new InterfaceType(name, superTypes);
			 supers.put(t, superTypes);
			 return t;
		case "library":
			return new LibraryType(name);
		case "contract":
			Set<CAstQualifier> quals = HashSetFactory.make();
			if (contractDefinition.has("abstract") && contractDefinition.getBoolean("abstract")) {
				quals.add(CAstQualifier.ABSTRACT);
			}
			 t = new ContractType(name, superTypes, quals);
			 supers.put(t, superTypes);
			 return t;
		default:
			assert false : contractDefinition;
			return null;
		}
	}

	private Pair<CAstType,String> parseNextTypeIdentifier(String typeId) {
		if (typeId.startsWith("t_mapping$_")) {
			Pair<CAstType, String> keyType = parseNextTypeIdentifier(typeId.substring(11));
			String rest = keyType.snd;
			if (rest.startsWith("_$_")) {
				Pair<CAstType, String> valueType = parseNextTypeIdentifier(rest.substring(3));
				String remaining = valueType.snd;
				if (remaining.startsWith("_$")) {
					return Pair.make(SolidityMappingType.get(keyType.fst, valueType.fst), remaining.substring(2));
				}
			}

		} else if (typeId.startsWith("t_tuple$_")) {
			List<CAstType> elts = new ArrayList<>();
			String remainder = typeId.substring(9);
			while (! remainder.startsWith("_$")) {
				Pair<CAstType,String> next = parseNextTypeIdentifier(remainder);
				remainder = next.snd;
				elts.add(next.fst);
			}
			return Pair.make(SolidityTupleType.get(elts.toArray(new CAstType[elts.size()])), remainder.substring(2));

		} else if (typeId.startsWith("t_magic_meta_type_")) {
			Pair<CAstType, String> x = parseNextTypeIdentifier(typeId.substring(19));
			return x;
			
		} else if (typeId.startsWith("t_magic_")) {
			int endIndex = typeId.indexOf('_', 8);
			if (endIndex > 0) {
				String type = typeId.substring(8, endIndex);
				return Pair.make(SolidityCAstType.get(type), typeId.substring(endIndex));
			} else {
				return Pair.make(SolidityCAstType.get(typeId.substring(8)),"");
			}

		} else if (typeId.startsWith("t_")) {
			int endIndex = typeId.indexOf('_', 2);
			if (endIndex > 0) {
				String type = typeId.substring(2, endIndex);
				return Pair.make(SolidityCAstType.get(type), typeId.substring(endIndex));
			} else {
				return Pair.make(SolidityCAstType.get(typeId.substring(2)),"");
			}
		}
		
		throw new RuntimeException("don't understand type " + typeId);
	}
	
	private CAstType parseTypeIdentifier(String typeId) {
		return parseNextTypeIdentifier(typeId).fst;
	}
	
	public class SolidityJSONTranslator implements TranslatorToCAst {

		private class TranslationVisitor implements JsonNodeTypeVisitor<CAstNode, SolidityWalkContext> {

			public Class<SolidityWalkContext> context() {
				return SolidityWalkContext.class;
			}

			private CAstType getTupleType(List<JSONObject> node) {
				return SolidityTupleType.get(node.stream().map(x -> getType(x)).toArray(i -> new CAstType[i]));
			}

			private JSONObject findSuperCall(JSONObject superDecl, CAstType type) {
				return null;
			}

			private Position getLocation(String string) {
				String[] bits = string.split(":");
				int startOffset = Integer.valueOf(bits[0]);
				int endOffset = startOffset + Integer.valueOf(bits[1]);
				String fileName = tree.getString("absolutePath");
				return new Position() {
					private int getLine(int offset) {
						return IntStream.range(0, linePositionMap.length).filter(i -> linePositionMap[i] > offset)
								.findFirst().orElse(linePositionMap.length) - 1;
					}

					private int getColumn(int offset) {
						int line = IntStream.range(0, linePositionMap.length).filter(i -> linePositionMap[i] > offset)
								.findFirst().orElse(linePositionMap.length);
						return offset - linePositionMap[line - 1];
					}

					@Override
					public int getFirstCol() {
						return getColumn(startOffset);
					}

					@Override
					public int getFirstLine() {
						return getLine(startOffset);
					}

					@Override
					public int getFirstOffset() {
						return startOffset;
					}

					@Override
					public int getLastCol() {
						return getColumn(endOffset);
					}

					@Override
					public int getLastLine() {
						return getLine(endOffset);
					}

					@Override
					public int getLastOffset() {
						return endOffset;
					}

					@Override
					public int compareTo(SourcePosition o) {
						return o.getFirstOffset() - getFirstOffset();
					}

					@Override
					public Reader getReader() throws IOException {
						return SolidityJSONTranslator.this.getReader();
					}

					@Override
					public URL getURL() {
						try {
							return URI.create("file:" + fileName).toURL();
						} catch (MalformedURLException e) {
							assert false : e;
							return null;
						}
					}

					@Override
					public String toString() {
						return "[" + getFirstOffset() + "-" + getLastOffset() + "]";
					}
				};
			}

			CAstOperator translateOpcode(String t) {
				switch (t) {
				case "!":
					return CAstOperator.OP_NOT;
				case "**":
					return CAstOperator.OP_POW;
				case "+":
				case "+=":
				case "++":
					return CAstOperator.OP_ADD;
				case "-":
				case "-=":
				case "--":
					return CAstOperator.OP_SUB;
				case "*":
				case "*=":
					return CAstOperator.OP_MUL;
				case "/":
				case "/=":
					return CAstOperator.OP_DIV;
				case "%":
				case "%=":
					return CAstOperator.OP_MOD;
				case "==":
					return CAstOperator.OP_EQ;
				case "!=":
					return CAstOperator.OP_NE;
				case "<":
					return CAstOperator.OP_LT;
				case "<=":
					return CAstOperator.OP_LE;
				case ">":
					return CAstOperator.OP_GT;
				case ">=":
					return CAstOperator.OP_GE;
				case "^":
				case "^=":
					return CAstOperator.OP_BIT_XOR;
				case "|":
				case "|=":
					return CAstOperator.OP_BIT_OR;
				case "&":
				case "&=":
					return CAstOperator.OP_BIT_AND;
				case "<<":
				case "<<=":
					return CAstOperator.OP_LSH;
				case ">>":
				case ">>=":
					return CAstOperator.OP_RSH;
				case ">>>":
				case ">>>=":
					return CAstOperator.OP_URSH;
				case "~":
					return CAstOperator.OP_BITNOT;
				default:
					return null;
				}
			}

			private CAstNode record(CAstNode expr, Position location, CAstType type, SolidityWalkContext context) {
				context.getNodeTypeMap().add(expr, type);
				context.pos().setPosition(expr, location);
				return expr;
			}

			private CAstNode getSelfPtr(SolidityWalkContext context) {
			    CAstNode thisPtr = ast.makeNode(CAstNode.THIS);
			    CAstType methodType = context.type();
			    context.getNodeTypeMap().add(thisPtr, methodType);
			    CAstNode selfPtr = ast.makeNode(CAstNode.OBJECT_REF, thisPtr, ast.makeConstant("self"));
			    context.getNodeTypeMap().add(selfPtr, ((FunctionType)methodType).getDeclaringType());
			    return selfPtr;				
			}
			
			public CAstNode handleIdentifierDeclaration(JSONObject decl, Position location, SolidityWalkContext context) {
				return (new JsonNodeTypeOnlyVisitor<CAstNode>() {
					@SuppressWarnings("unused")
					public CAstNode visitVariableDeclaration(JSONObject decl, Void ignore) {
						if (decl.getBoolean("constant")) {
							return TranslationVisitor.this.visit(decl.getJSONObject("value"), context);
						} else {
							CAstNode name = ast.makeConstant(decl.getString("name"));
							Position position = getLocation(decl.getString("src"));
							CAstType type = getType(decl.getJSONObject("typeName"));
							if (decl.has("stateVariable") && decl.getBoolean("stateVariable")) {
								CAstNode self = getSelfPtr(context);
								return record(ast.makeNode(CAstNode.OBJECT_REF, self, name), position, type, context);
							} else {
								return record(ast.makeNode(CAstNode.VAR, name), position, type, context);
							}
						}
					}

					@SuppressWarnings("unused")
					public CAstNode visitFunctionDefinition(JSONObject decl, Void ignore) {
						CAstType et = findOrCreateType(decl, JSONToCAst.this::newFunctionType);
						CAstNode selfPtr = getSelfPtr(context);
						String name = decl.has("constructor") && decl.getBoolean("constructor")? "<init>": decl.getString("name");
						return record(ast.makeNode(CAstNode.OBJECT_REF, selfPtr, ast.makeConstant(name)), location, et, context);
					}

					@SuppressWarnings("unused")
					public CAstNode visitEventDefinition(JSONObject decl, Void ignore) {
						CAstType et = findOrCreateType(decl, JSONToCAst.this::newFunctionType);
						CAstNode selfPtr = getSelfPtr(context);
						return record(ast.makeNode(CAstNode.OBJECT_REF, selfPtr, ast.makeConstant(decl.getString("name"))), location, et, context);
					}
					
				}).visit(decl, null);
			}

			private interface VariableContainerContext extends SolidityWalkContext {
				@Override
				default void registerVariable(String name, CAstEntity field) {
					variables().put(name, field);
				}

			}

			private interface FunctionContainerContext extends SolidityWalkContext {
				@Override
				default void registerFunction(String name, CAstEntity field) {
					functions().put(name, field);
				}
			}

			private SolidityWalkContext contractContext(JSONObject contract, SolidityWalkContext parent) {

				class ContractContext implements VariableContainerContext, FunctionContainerContext {
					private final Map<String, CAstEntity> vars = HashMapFactory.make();
					private final Map<String, CAstEntity> functions = HashMapFactory.make();

					@Override
					public WalkContext<SolidityWalkContext, JSONObject> getParent() {
						return parent;
					}

					@Override
					public Map<String, CAstEntity> variables() {
						return vars;
					}

					@Override
					public Map<String, CAstEntity> functions() {
						return functions;
					}

					@Override
					public JSONObject contract() {
						return contract;
					}

					@Override
					public CAstType type() {
						return findOrCreateType(contract, JSONToCAst.this::newContractType);
					}
					
					public String toString() {
						return "context for contract " + contract.getString("name");
					}
				}

				return new ContractContext();
			}

			private SolidityWalkContext variableContainerContext(SolidityWalkContext parent) {
				return new VariableContainerContext() {
					private final Map<String, CAstEntity> vars = HashMapFactory.make();

					@Override
					public WalkContext<SolidityWalkContext, JSONObject> getParent() {
						return parent;
					}

					@Override
					public Map<String, CAstEntity> variables() {
						return vars;
					}
				};
			}

			private SolidityWalkContext codeContext(FunctionEntity funEntity, SolidityWalkContext context) {
				return new VariableContainerContext() {
					private final Map<String, CAstEntity> vars = HashMapFactory.make();

					@Override
					public WalkContext<SolidityWalkContext, JSONObject> getParent() {
						return context;
					}

					@Override
					public Map<String, CAstEntity> variables() {
						return vars;
					}

					@Override
					public CAstType type() {
						return funEntity.getType();
					}
					
					public String toString() {
						return "context for " + funEntity;
					}

					
					@Override
					public CAstSourcePositionRecorder pos() {
						return funEntity.getSourceMap();
					}

					@Override
					public CAstNodeTypeMapRecorder getNodeTypeMap() {
						return funEntity.getNodeTypeMap();
					}
					
					
				};
			}


			CallableEntity visitCallableDefinition(JSONObject def, CAstType retType, boolean isCtor, SolidityWalkContext context) {
				ids.put(def.getInt("id"), def);
				
				JSONArray parameters = def.getJSONObject("parameters").getJSONArray("parameters");
				
				Streams.stream(parameters.iterator()).forEach(x -> { 
					JSONObject p = (JSONObject)x;
					ids.put(p.getInt("id"), p);
				});
				
				String funName = isCtor ? "<init>" : def.getString("name");
				CAstType[] parameterTypes = Streams.stream(parameters.iterator())
						.map(x -> getType(((JSONObject) x).getJSONObject("typeName"))).toArray(x -> new CAstType[x]);

				JSONObject cls = context.contract();
				CAstType.Class selfType = (cls != null) ? findOrCreateType(cls, JSONToCAst.this::newContractType)
						: null;

				CAstType.Function funType = FunctionType.findOrCreate(funName, selfType, retType, parameterTypes);
				Position loc = getLocation(def.getString("src"));

				Position[] parameterLocs = Streams.stream(parameters.iterator())
						.map(x -> getLocation(((JSONObject) x).getString("src"))).toArray(x -> new Position[x]);

				String[] parameterNames = Streams.stream(parameters.iterator())
						.map(x -> ((JSONObject) x).getString("name")).toArray(x -> new String[x]);

				Set<CAstQualifier> qualSet = HashSetFactory.make();

				if (isCtor) {
					qualSet.add(CAstQualifier.PUBLIC);
				} else {
					if (def.has("visibility")) {
					switch (def.getString("visibility")) {
					case "default":
					case "private":
						qualSet.add(CAstQualifier.PRIVATE);
						break;
					case "internal":
						qualSet.add(CAstQualifier.PROTECTED);
						break;
					case "external":
						qualSet.add(CAstQualifier.EXTERNAL);
					case "public":
						qualSet.add(CAstQualifier.PUBLIC);
					}
					}
				}
				if (def.has("virtual") && def.getBoolean("virtual")) {
					qualSet.add(CAstQualifier.VIRTUAL);
				}

				boolean isEvent = "EventDefinition".equals(def.get("nodeType"));
				boolean isError = "ErrorDefinition".equals(def.get("nodeType"));

				if (isEvent || isError) {
					return new EventEntity(funName, funType, parameterNames, loc, null, parameterLocs, qualSet, null);
				} else {
					return new FunctionEntity(funName, funType, parameterNames, loc, null, parameterLocs, qualSet,
							null);
				}
			}

			@Override
			public CAstNode visitNode(JSONObject o, SolidityWalkContext context) {
				o.keys().forEachRemaining(k -> {
					if (o.get(k) instanceof JSONObject) {
						visit(o.getJSONObject(k), context);
					} else if (o.get(k) instanceof JSONArray) {
						JSONArray x = o.getJSONArray(k);
						for (int i = 0; i < x.length(); i++) {
							if (x.get(i) instanceof JSONObject) {
								visit(x.getJSONObject(i), context);
							}
						}
					}
				});
				return ast.makeNode(CAstNode.EMPTY);
			}

			@SuppressWarnings("unused")
			public CAstNode visitAssignment(JSONObject o, SolidityWalkContext context) {
				CAstNode lhs = visit(o.getJSONObject("leftHandSide"), context);
				CAstNode rhs = visit(o.getJSONObject("rightHandSide"), context);

			    String op = o.getString("operator");
			    
			    return record(("=".equals(op)?
			               ast.makeNode(CAstNode.ASSIGN, lhs, rhs):
			               ast.makeNode(CAstNode.ASSIGN_POST_OP, lhs, rhs, translateOpcode(op))),
			            getLocation(o.getString("src")), null, context);
			}
		
			@SuppressWarnings("unused")
			public CAstNode visitBinaryOperation(JSONObject o, SolidityWalkContext context) {
				String op = o.getString("operator");
				CAstNode expr;
				CAstNode left = visit(o.getJSONObject("leftExpression"), context);
				CAstNode right = visit(o.getJSONObject("rightExpression"), context);
				if ("&&".equals(op)) {
					expr = ast.makeNode(CAstNode.IF_EXPR, left, right, ast.makeConstant(false));
				} else if ("||".equals(op)) {
					expr = ast.makeNode(CAstNode.IF_EXPR, left, ast.makeConstant(true), right);
				} else {
					CAstNode operator = translateOpcode(op);
					expr = ast.makeNode(CAstNode.BINARY_EXPR, operator, left, right);
				}

				record(expr, getLocation(o.getString("src")), getType(o), context);

				return expr;
			}

			@SuppressWarnings("unused")
			public CAstNode visitBlock(JSONObject o, SolidityWalkContext context) {
				return ast.makeNode(CAstNode.BLOCK_STMT, Streams.stream(o.getJSONArray("statements").iterator())
						.map(n -> visit((JSONObject) n, context)).toList());
			}

			@SuppressWarnings("unused")
			public CAstNode visitConditional(JSONObject o, SolidityWalkContext context) {
				return record(ast.makeNode(CAstNode.IF_EXPR, 
						visit(o.getJSONObject("condition"), context),
						visit(o.getJSONObject("trueExpression"), context),
						visit(o.getJSONObject("falseExpression"), context)),
						getLocation(o.getString("src")),
						null,
						context);	
			}

			@SuppressWarnings("unused")
			public CAstNode visitContractDefinition(JSONObject o, SolidityWalkContext context) {
				ids.put(o.getInt("id"), o);
				CAstType.Class contractType = (CAstType.Class) getType(o);
				SolidityWalkContext child = contractContext(o, context);

				for(String s : new String[] {"nodes", "baseContracts"}) {
					if (o.has(s)) {
						o.getJSONArray(s).forEach(m -> {
							visit((JSONObject) m, child);
						});
					}
				}
				
				Set<CAstEntity> elts = HashSetFactory.make(
						child.variables().entrySet().stream().map(m -> m.getValue()).collect(Collectors.toSet()));
				elts.addAll(child.functions().entrySet().stream().map(m -> m.getValue()).collect(Collectors.toSet()));

				ContractEntity contractEntity = new ContractEntity(contractType, getLocation(o.getString("src")), null,
						elts);

				context.addScopedEntity(null, contractEntity);

				return ast.makeNode(CAstNode.EMPTY);
			}

			@SuppressWarnings("unused")
			public CAstNode visitElementaryTypeNameExpression(JSONObject o, SolidityWalkContext context) {
				CAstType type = getType(o.getJSONObject("typeName"));
				return record(ast.makeNode(CAstNode.TYPE_LITERAL_EXPR, ast.makeConstant(type.getName())), getLocation(o.getString("src")), type, context);
			}
			
			@SuppressWarnings("unused")
			public CAstNode visitEmitStatement(JSONObject o, SolidityWalkContext context) {
				return record(visit(o.getJSONObject("eventCall"), context), getLocation(o.getString("src")), null, context);
			}

			@SuppressWarnings("unused")
			public CAstNode visitEnumDefinition(JSONObject o, SolidityWalkContext context) {
				ids.put(o.getInt("id"), o);
				String enumName = o.getString("canonicalName");

				List<String> members = Streams.stream(o.getJSONArray("members").iterator())
						.map(e -> ((JSONObject) e).getString("name")).toList();

				new EnumType(enumName, members);

				return ast.makeNode(CAstNode.EMPTY);
			}

			@SuppressWarnings("unused")
			public CAstNode visitErrorDefinition(JSONObject o, SolidityWalkContext context) {
				ids.put(o.getInt("id"), o);
				
			    EventEntity funEntity = (EventEntity) visitCallableDefinition(o, null, false, context);
			    
			    context.registerFunction(o.getString("name"), funEntity);

			     return ast.makeNode(CAstNode.EMPTY);
			}

			@SuppressWarnings("unused")
			public CAstNode visitEventDefinition(JSONObject o, SolidityWalkContext context) {
				ids.put(o.getInt("id"), o);
				
			    EventEntity funEntity = (EventEntity) visitCallableDefinition(o, null, false, context);
			    
			    context.registerFunction(o.getString("name"), funEntity);

			     return ast.makeNode(CAstNode.EMPTY);
			}

			@SuppressWarnings("unused")
			public CAstNode visitExpressionStatement(JSONObject o, SolidityWalkContext context) {
				return record(visit(o.getJSONObject("expression"), context), getLocation(o.getString("src")), null, context);
			}

			 private static class SolidityLoopContext extends TranslatorToCAst.LoopContext<SolidityWalkContext, JSONObject>
		        implements SolidityWalkContext {

		      SolidityLoopContext(SolidityWalkContext parent, JSONObject breakTo, JSONObject continueTo) {
		        super(parent, breakTo, continueTo, null);
		      }

		      private boolean continued = false;
		      private boolean broke = false;

		      @Override
		      public JSONObject getContinueFor(String l) {
		        continued = true;
		        return super.getContinueFor(l);
		      }

		      @Override
		      public JSONObject getBreakFor(String l) {
		        broke = true;
		        return super.getBreakFor(l);
		      }
		    }
			
			@SuppressWarnings("unused")
			public CAstNode visitForStatement(JSONObject o, SolidityWalkContext context) {
				CAstNode test = visit(o.getJSONObject("condition"), context);
				CAstNode init = visit(o.getJSONObject("initializationExpression"), context);
				CAstNode update = visit(o.getJSONObject("loopExpression"), context);
				
				JSONObject contLabel = JSONObject.fromJson("{\"nodeType\": \"Continue\"}", JSONObject.class);
				JSONObject breakLabel = JSONObject.fromJson("{\"nodeType\": \"Break\"}", JSONObject.class);
				SolidityLoopContext lc = new SolidityLoopContext(context, breakLabel, contLabel);
				CAstNode body = visit(o.getJSONObject("body"), lc);
				
				if (lc.continued) {
					body = ast.makeNode(CAstNode.BLOCK_STMT, body, ast.makeNode(CAstNode.LABEL_STMT, ast.makeConstant("cont" + idx++), visit(contLabel, context)));
				}
				
				CAstNode result = ast.makeNode(CAstNode.BLOCK_STMT, 
					init, 
					ast.makeNode(CAstNode.LOOP, 
						test,
						ast.makeNode(CAstNode.BLOCK_STMT, body, update)));
				
				if (lc.broke) {
					result = ast.makeNode(CAstNode.BLOCK_STMT, result, ast.makeNode(CAstNode.LABEL_STMT, ast.makeConstant("break" + idx++), visit(breakLabel, context)));
				}
				
				return result;
			}

			@SuppressWarnings("unused")
			public CAstNode visitFunctionCall(JSONObject o, SolidityWalkContext context) {
				CAstNode fun = visit(o.getJSONObject("expression"), context);
				CAstNode[] args = Streams.concat(Streams.stream(Optional.of(ast.makeNode(CAstNode.EMPTY))), Streams.stream(o.getJSONArray("arguments").iterator()).map(v -> (JSONObject)v).map(v -> visit(v, context))).toArray(i -> new CAstNode[i]);
				return record(ast.makeNode(CAstNode.CALL, fun, args), getLocation(o.getString("src")), getType(o), context);
			}
			
			@SuppressWarnings("unused")
			public CAstNode visitFunctionDefinition(JSONObject o, SolidityWalkContext context) {
				CAstType retType;
				JSONArray rets = o.getJSONObject("returnParameters").getJSONArray("parameters");
				if (rets.length() == 0) {
					retType = null;
				} else if (rets.length() == 1) {
					retType = getType(rets.getJSONObject(0).getJSONObject("typeName"));
				} else {
					retType = SolidityTupleType.get(getTypes(rets));
				}

				FunctionEntity funEntity = (FunctionEntity) visitCallableDefinition(o, retType,
						"constructor".endsWith(o.getString("kind")), context);

				if (o.has("mutability")) {
					String mutability = o.getString("mutability");
					if ("pure".equals(mutability)) {
						funEntity.addQualifier(CAstQualifier.PURE);
					} else if ("view".equals(mutability)) {
						funEntity.addQualifier(CAstQualifier.CONST);
					}
				}
				
				if ("library".equals(ids.get(o.getInt("scope")).get("contractKind"))) {
					funEntity.addQualifier(CAstQualifier.STATIC);
				}

				if (!o.getBoolean("implemented")) {
					funEntity.addQualifier(CAstQualifier.ABSTRACT);

				} else {
					SolidityWalkContext child = codeContext(funEntity, context);

					Streams
					.stream(o.getJSONObject("returnParameters").getJSONArray("parameters").iterator())
					.map(d -> (JSONObject)d)
					.filter(d -> d.has("name") && !"".equals(d.getString("name")))
					.forEach(d -> visit(d, child));
					
					CAstNode body = visit(o.getJSONObject("body"), child);
					
					if ("constructor".equals(o.getString("kind"))) {
						Streams.stream(o.getJSONArray("modifiers").iterator()).forEach(x -> {
							JSONObject scs = (JSONObject) x;
							JSONObject superDecl = ids
									.get(scs.getJSONObject("modifierName").getInt("referencedDeclaration"));
							if ("contractDefinition".equals(superDecl.getString("nodeType"))) {
								JSONObject ctor = findSuperCall(superDecl, funEntity.getType());
								CAstNode callee;
								if ((callee = handleIdentifierDeclaration(ctor,
										getLocation(scs.getString("src")), context)) != null) {
									CAstNode[] args = Streams.stream(scs.getJSONArray("arguments").iterator())
											.map(a -> visit((JSONObject) a, context)).toArray(n -> new CAstNode[n]);

									record(ast.makeNode(CAstNode.CALL, callee, args), getLocation(scs.getString("src")),
											null, context);
								}
							}
						});
					}

					List<CAstNode> retDecls = new ArrayList<>(Streams
							.stream(o.getJSONObject("returnParameters").getJSONArray("parameters").iterator())
							.filter(x -> ((JSONObject) x).has("name") && !"".equals(((JSONObject)x).getString("name"))).map(x -> {
								JSONObject p = (JSONObject) x;
								CAstSymbol symbol = new CAstSymbolImpl(p.getString("name"), getType(p), false);
								return ast.makeNode(CAstNode.BLOCK_STMT,
										ast.makeNode(CAstNode.DECL_STMT, ast.makeConstant(symbol)),
										ast.makeNode(CAstNode.ASSIGN, 
											ast.makeNode(CAstNode.VAR, ast.makeConstant(p.getString("name"))),
											ast.makeConstant(0)));
							}).toList());

					if (retDecls.size() > 0) {
						CAstNode ret = ast.makeNode(CAstNode.RETURN, Streams
								.stream(o.getJSONObject("returnParameters").getJSONArray("parameters").iterator())
								.map(x -> ast.makeNode(CAstNode.VAR,
										ast.makeConstant(((JSONObject) x).getString("name"))))
								.toList());
						body = ast.makeNode(CAstNode.BLOCK_STMT, body, ret);
						// getLocation(o.getJSONObject("returnParameters").getString("src"))
					}

					retDecls.add(body);
					body = ast.makeNode(CAstNode.BLOCK_STMT, retDecls);

					funEntity.setAst(body);
				}

				context.registerFunction(o.getString("name"), funEntity);
				return ast.makeNode(CAstNode.EMPTY);
			}

			private boolean isMagicIdentifier(JSONObject id) {
				return id.getInt("referencedDeclaration") < 0;
			}
			
			@SuppressWarnings("unused")
			public CAstNode visitIdentifier(JSONObject o, SolidityWalkContext context) {
				if (isMagicIdentifier(o)) {
					if ("this".equals(o.getString("name"))) {
						return getSelfPtr(context);
					} else {
						return record(ast.makeNode(CAstNode.PRIMITIVE, ast.makeConstant(o.getString("name")), ast.makeConstant(getType(o))), getLocation(o.getString("src")), getType(o), context);
					}
				} else {
					return handleIdentifierDeclaration(ids.get(o.getInt("referencedDeclaration")), getLocation(o.getString("src")), context);
				}
			}
			
			@SuppressWarnings("unused")
			public CAstNode visitIfStatement(JSONObject o, SolidityWalkContext context) {
				return record(ast.makeNode(CAstNode.IF_STMT, 
						visit(o.getJSONObject("condition"), context),
						visit(o.getJSONObject("trueBody"), context),
						visit(o.getJSONObject("falseBody"), context)),
						getLocation(o.getString("src")),
						null,
						context);	
			}

			@SuppressWarnings("unused")
			public CAstNode visitIndexAccess(JSONObject o, SolidityWalkContext context) {
				CAstNode obj = visit(o.getJSONObject("baseExpression"), context);
				if (o.has("indexExpression")) {
					CAstType eltType = getType(o);
					JSONObject idxExpr = o.getJSONObject("indexExpression");
					return record(ast.makeNode(CAstNode.ARRAY_REF, obj, ast.makeConstant(eltType), visit(idxExpr, context)), getLocation(o.getString("src")), eltType, context);
				} else {
					CAstType bt = getType(o.getJSONObject("baseExpression"));
					CAstType at = SolidityArrayType.get(bt);
					return record(ast.makeNode(CAstNode.TYPE_LITERAL_EXPR, ast.makeConstant(at.getName())),getLocation(o.getString("src")), at, context); 
				}
			}
			
			@SuppressWarnings("unused")
			public CAstNode visitInheritanceSpecifier(JSONObject o, SolidityWalkContext context) {
				CAstType superType = getType(ids.get(o.getJSONObject("baseName").getInt("referencedDeclaration")));
				supers.get(context.type()).add(superType.getName());
				return ast.makeNode(CAstNode.EMPTY);
			}
	
			@SuppressWarnings("unused")
			public CAstNode visitLiteral(JSONObject o, SolidityWalkContext context) {
				switch (o.getString("kind")) {
				case "string": return record(ast.makeConstant(o.getString("value")), getLocation(o.getString("src")), getType(o), context);
				case "bool": return record(ast.makeConstant(o.getBoolean("value")), getLocation(o.getString("src")), getType(o), context);
				case "number": 
					Number n;
					BigInteger i = new BigInteger(o.getString("value"));
					try {
						n = Integer.valueOf(i.intValueExact());
					} catch (ArithmeticException e) {
						try {
							n = Long.valueOf(i.longValueExact());						
						} catch (ArithmeticException e1) {
							n = i;
						}
					}
					return record(ast.makeConstant(n), getLocation(o.getString("src")), getType(o), context);
				default:
					return ast.makeNode(CAstNode.EMPTY);
				}
			} 
	
			@SuppressWarnings("unused")
			public CAstNode visitMemberAccess(JSONObject o, SolidityWalkContext context) {
				return new JsonNodeTypeOnlyVisitor<CAstNode>() {
					public CAstNode visitVariableDeclaration(JSONObject vd, Void ignore) {
						if (vd.has("constant") && vd.getBoolean("constant")) {
							return TranslationVisitor.this.visit(vd.getJSONObject("value"), context);
						} else {
							return visitNode(o, null);
						}
					}

					public CAstNode visitCallableDefinition(JSONObject fd, Void ignore) {
						FunctionType type = findOrCreateType(fd, JSONToCAst.this::newFunctionType);
						CAstNode ref = makeRef(o, type);
						context.getNodeTypeMap().add(ref, type);
						return ref;
					}

					public CAstNode visitFunctionDefinition(JSONObject fd, Void ignore) {
						return visitCallableDefinition(fd, null);
					}
					
					public CAstNode visitEventDfinition(JSONObject fd, Void ignore) {
						return visitCallableDefinition(fd, null);
					}
					
					public CAstNode visitErrorDefinition(JSONObject fd, Void ignore) {
						return visitCallableDefinition(fd, null);
					}

					@Override
					public CAstNode visitNode(JSONObject o, Void ignore) {
						CAstNode ref = makeRef(o, getType(o));
						context.getNodeTypeMap().add(ref, getType(o));
						return ref;
					}
					
					private CAstNode makeRef(JSONObject obj, CAstType type) {
						return record(
							ast.makeNode(CAstNode.OBJECT_REF, 
								TranslationVisitor.this.visit(obj.getJSONObject("expression"), context),
								ast.makeConstant(o.getString("memberName"))),
							getLocation(o.getString("src")), type, context);
					}
					
				}.visit(ids.get(o.getInt("referencedDeclaration")), null);
			}
			
			@SuppressWarnings("unused")
			public CAstNode visitSourceUnit(JSONObject o, SolidityWalkContext context) {
				return ast.makeNode(CAstNode.BLOCK_STMT, Streams.stream(o.getJSONArray("nodes").iterator())
						.map(n -> visit((JSONObject) n, context)).toList());
			}

			@SuppressWarnings("unused")
			public CAstNode visitStructDefinition(JSONObject o, SolidityWalkContext context) {
				ids.put(o.getInt("id"), o);
				SolidityWalkContext child = variableContainerContext(context);

				o.getJSONArray("members").forEach(m -> {
					visit((JSONObject) m, child);
				});

				StructType structType = (StructType) getType(o);

				Set<CAstEntity> elts = context.variables().entrySet().stream().map(m -> m.getValue())
						.collect(Collectors.toSet());

				ContractEntity structEntity = new ContractEntity(structType, getLocation(o.getString("src")), null,
						elts);

				context.addScopedEntity(null, structEntity);

				return ast.makeNode(CAstNode.EMPTY);
			}

			@SuppressWarnings("unused")
			public CAstNode visitTupleExpression(JSONObject o, SolidityWalkContext context) {
				JSONArray components = o.getJSONArray("components");
				if (components.length() == 1) {
					return visit(components.getJSONObject(0), context);
				} else {
					CAstType tt = SolidityTupleType.get(Streams.stream(components.iterator()).map(x -> (JSONObject)x).map(x -> getType(x)).toArray(i -> new CAstType[i]));
					CAstNode[] args = Streams.stream(components.iterator()).map(x -> (JSONObject)x).map(x -> visit(x, context)).toArray(i -> new CAstNode[i]);
					return record(ast.makeNode(CAstNode.NEW,
						ast.makeConstant(tt),
						args), getLocation(o.getString("src")), tt, context);
				}
			}
			
			@SuppressWarnings("unused")
			public CAstNode visitUnaryOperation(JSONObject o, SolidityWalkContext context) {
				CAstNode operand = visit(o.getJSONObject("subExpression"), context);

				String opName = o.getString("operator");
				CAstOperator op = translateOpcode(opName);

				CAstNode expr;
				if ("++".equals(opName) || "--".equals(opName)) {
					expr = ast.makeNode((o.getBoolean("prefix") ? CAstNode.ASSIGN_PRE_OP : CAstNode.ASSIGN_POST_OP),
							operand, ast.makeConstant(1), op);
				} else if ("delete".equals(opName)) {
					expr = ast.makeNode(CAstNode.PRIMITIVE, ast.makeConstant("delete"), operand);
				} else {
					expr = ast.makeNode(CAstNode.UNARY_EXPR, op, operand);
				}

				record(expr, getLocation(o.getString("src")), getType(o), context);
				return expr;
			}

			private boolean isStructField(JSONObject decl) {
				int scope = decl.getInt("scope");
				return ids.containsKey(scope) && "StructDefinition".equals(ids.get(scope).getString("nodeType"));
			}

			private boolean isContractField(JSONObject decl) {
				return decl.has("stateVariable") && decl.getBoolean("stateVariable");
			}

			@SuppressWarnings("unused")
			public CAstNode visitVariableDeclaration(JSONObject o, SolidityWalkContext context) {
				ids.put(o.getInt("id"), o);
				Position pos = getLocation(o.getString("src"));
				CAstType type = getType(o.getJSONObject("typeName"));
				boolean isFinal = o.has("constant") && o.getBoolean("constant");
				String name = o.getString("name");

				if (isStructField(o) || isContractField(o)) {
					CAstEntity f = new AbstractFieldEntity(name, type,
							isFinal ? Collections.singleton(CAstQualifier.FINAL) : Collections.emptySet(), false, pos,
							null);
					context.registerVariable(name, f);
					return ast.makeNode(CAstNode.EMPTY);
				} else {
					CAstNode v = o.has("initialValue") ? visit(o.getJSONObject("initialValue"), context) : null;
					CAstSymbol symbol = new CAstSymbolImpl(name, type, isFinal);
					CAstNode result = ast.makeNode(CAstNode.DECL_STMT, ast.makeConstant(symbol));
					record(result, pos, type, context);
					return result;
				}
			}

			@SuppressWarnings("unused")
			public CAstNode visitVariableDeclarationStatement(JSONObject o, SolidityWalkContext context) {
				List<CAstNode> decls = Streams.stream(o.getJSONArray("declarations").iterator())
						.map(d -> d == null ? ast.makeNode(CAstNode.EMPTY) : visit((JSONObject) d, context)).toList();

				if (o.has("initialValue")) {
					decls = new ArrayList<>(decls);
					String name = "decl" + idx++;
					decls.add(ast.makeNode(CAstNode.DECL_STMT,
							ast.makeConstant(new CAstSymbolImpl(name, CAstType.DYNAMIC))));
					decls.add(ast.makeNode(CAstNode.ASSIGN, ast.makeNode(CAstNode.VAR, ast.makeConstant(name)),
							visit(o.getJSONObject("initialValue"), context)));
					decls.add(ast.makeNode(CAstNode.ASSIGN,
							ast.makeNode(CAstNode.NEW,
									ast.makeConstant(getTupleType(Streams.stream(o.getJSONArray("declarations").iterator())
											.map(x -> ((JSONObject) x).getJSONObject("typeName")).toList())),
									Streams.stream(o.getJSONArray("declarations").iterator())
											.map(d -> d == null ? ast.makeNode(CAstNode.EMPTY)
													: ast.makeNode(CAstNode.VAR,
															ast.makeConstant(((JSONObject) d).getString("name"))))
											.toArray(i -> new CAstNode[i])),
							ast.makeNode(CAstNode.VAR, ast.makeConstant(name))));
				}

				return ast.makeNode(CAstNode.BLOCK_STMT, decls);
			}

			@SuppressWarnings("unused")
			public CAstNode visitInlineAssembly(JSONObject o, SolidityWalkContext context) {
				JSONObject yulAst = o.getJSONObject("AST");

				Map<String, JSONObject> info = HashMapFactory.make();
				Streams.stream(o.getJSONArray("externalReferences").iterator()).forEach(e -> {
					JSONObject ej = (JSONObject) e;
					info.put(ej.getString("src"), ej);
				});

				class YulExpressionVisitor implements JsonNodeTypeOnlyVisitor<CAstNode> {
					public CAstNode visitYulIdentifier(JSONObject o, Void ignore) {
						String src = o.getString("src");
						String name = o.getString("name");
						if (info.containsKey(src)) {
							JSONObject decl = ids.get(info.get(src).getInt("declaration"));
							return handleIdentifierDeclaration(decl, getLocation(src), context);
						} else {
							int dot = name.indexOf('.');
							if (dot >= 0) {
								String obj = name.substring(0, dot);
								String field = name.substring(dot + 1);
								return ast.makeNode(CAstNode.OBJECT_REF,
										ast.makeNode(CAstNode.VAR, ast.makeConstant(obj)), ast.makeConstant(field));
							} else {
								return ast.makeNode(CAstNode.VAR, ast.makeConstant(name));
							}
						}
					}
				}

				class YulStatementVisitor implements JsonNodeTypeOnlyVisitor<CAstNode> {
					public CAstNode visitYulExpressionStatement(JSONObject o, Void context) {
						return new YulExpressionVisitor().visit(o.getJSONObject("expression"), context);
					}

					public CAstNode visitYulBlock(JSONObject o, SolidityWalkContext context) {
						return ast.makeNode(CAstNode.BLOCK_STMT, Streams.stream(o.getJSONArray("statements").iterator())
								.map(e -> visit((JSONObject) o, null)).toList());
					}
				}

				return new YulStatementVisitor().visit(yulAst, null);
			}
		}

		public SolidityJSONTranslator(JSONObject tree) {
			this.tree = tree;
		}

		private final JSONObject tree;
		private File sourceFile;
		private int[] linePositionMap;

		private Reader getReader() throws FileNotFoundException {
			return new FileReader(sourceFile);
		}

		@Override
		public <C extends RewriteContext<K>, K extends CopyKey<K>> void addRewriter(CAstRewriterFactory<C, K> factory,
				boolean prepend) {
			// TODO Auto-generated method stub
		}

		@Override
		public CAstEntity translateToCAst() throws Error, IOException {
			sourceFile = new File(tree.getString("absolutePath"));
			String[] lines = new String(Files.readAllBytes(Paths.get(sourceFile.toURI())), "UTF-8").split("\n");
			linePositionMap = new int[lines.length + 1];
			int total = 0;
			for (int i = 0; i < lines.length; i++) {
				linePositionMap[i + 1] = total;
				total += (lines[i].length() + 1);
			}

			System.err.println("translating " + sourceFile);
			
			final AbstractEntity fileEntity = new AbstractEntity() {
				CAstSourcePositionRecorder rec = new CAstSourcePositionRecorder();
				
				@Override
				public int getKind() {
					return CAstEntity.FILE_ENTITY;
				}

				@Override
				public String getName() {
					return tree.getString("absolutePath");
				}

				@Override
				public CAstNode getAST() {
					assert false;
					return null;
				}

				@Override
				public int getArgumentCount() {
					assert false;
					return 0;
				}

				@Override
				public CAstNode[] getArgumentDefaults() {
					assert false;
					return null;
				}

				@Override
				public String[] getArgumentNames() {
					return new String[0];
				}

				@Override
				public CAstControlFlowMap getControlFlow() {
					assert false;
					return null;
				}

				@Override
				public Position getNamePosition() {
					assert false;
					return null;
				}

				@Override
				public CAstNodeTypeMap getNodeTypeMap() {
					assert false;
					return null;
				}

				@Override
				public Position getPosition(int arg) {
					assert false;
					return null;
				}

				@Override
				public Collection<CAstQualifier> getQualifiers() {
					assert false;
					return null;
				}

				@Override
				public CAstSourcePositionMap getSourceMap() {
					return rec;
				}

				@Override
				public CAstType getType() {
					assert false;
					return null;
				}
			};

			System.err.println(new TranslationVisitor().visit(tree, new SolidityWalkContext() {
				@Override
				public WalkContext<SolidityWalkContext, JSONObject> getParent() {
					return null;
				} 
				
				public String toString() {
					return "root context for " + sourceFile;
				}

				@Override
				public void addScopedEntity(CAstNode newNode, CAstEntity visit) {
					fileEntity.addScopedEntity(newNode, visit);
				}
		
			}));
			
			return fileEntity;
		}
	}

	public void translateFiles(String compilerOutputFile) throws Error, IOException {
		System.err.println("parsing " + compilerOutputFile);
		JSONTokener toks = new JSONTokener(new FileReader(compilerOutputFile));
		while (toks.more()) {
			Object tok;
			try {
				tok = toks.nextValue();
			} catch (JSONException e) {
				toks.next();
				continue;
			}

			if (tok instanceof JSONObject && ((JSONObject) tok).has("absolutePath")) {
				System.err.println(CAstPrinter.print(new SolidityJSONTranslator((JSONObject) tok).translateToCAst()));
			}
		}
	}

}
