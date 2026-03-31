//
//  solidityBridge.h
//  WALA CAst Solidity
//
//  Created by Julian Dolby on 12/18/25.
//
#include <fstream>
#include <sstream>

#include <liblangutil/CharStream.h>
#include <liblangutil/ErrorReporter.h>
#include <libsolidity/parsing/Parser.h>
#include <libsolidity/analysis/TypeChecker.h>
#include <libsolidity/analysis/StaticAnalyzer.h>
#include <libsolidity/analysis/Scoper.h>
#include <libsolidity/analysis/NameAndTypeResolver.h>
#include <libsolidity/analysis/GlobalContext.h>
#include <libsolidity/analysis/SyntaxChecker.h>
#include <libsolidity/analysis/ReferencesResolver.h>
#include <libsolidity/analysis/DocStringTagParser.h>
#include <libsolidity/interface/CompilerStack.h>

#include <assert.h>

solidity::StringMap gatherSources(int argc, char const**argv);
void compileSources(solidity::frontend::CompilerStack& compiler, const solidity::StringMap &sources);
