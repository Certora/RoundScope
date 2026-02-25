//
//  solidityBridge.cpp
//  WALA CAst Solidity
//
//  Created by Julian Dolby on 12/18/25.
//
#include "solidityBridge.h"

solidity::StringMap gatherSources(int argc, char const**argv) {
    solidity::StringMap sources;
    
    for(int i = 0; i < argc; i+=2) {
        std::string a1 = std::string(argv[i]);
        std::string a2 = std::string(argv[i+1]);
        
        std::wifstream t(a1);
        std::wstringstream buffer;
        buffer << t.rdbuf();
        std::wstring wfile = buffer.str();
        const std::string file( wfile.begin(), wfile.end() );

        sources[a1] = file;
    }
    return sources;
}

void compileSources(
    solidity::frontend::CompilerStack& compiler,
    const solidity::StringMap &sources)
{
    compiler.setSources(sources);
    
    compiler.parseAndAnalyze(solidity::frontend::CompilerStack::State::AnalysisSuccessful);
    
    std::cout << compiler.state() << " " << solidity::frontend::CompilerStack::State::AnalysisSuccessful << std::endl;
}
