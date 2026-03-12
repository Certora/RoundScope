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
    for (auto const& s : sources) {
        std::cerr << "source: " << s.first << " (" << s.second.size() << " bytes)" << std::endl;
    }

    compiler.setSources(sources);

    try {
        bool success = compiler.parseAndAnalyze(solidity::frontend::CompilerStack::State::AnalysisSuccessful);

        std::cerr << "parseAndAnalyze: " << (success ? "success" : "FAILED") << std::endl;
        std::cerr << "compiler state: " << compiler.state() << " (target: " << solidity::frontend::CompilerStack::State::AnalysisSuccessful << ")" << std::endl;

        if (!success) {
            for (auto const& error : compiler.errors()) {
                std::cerr << "  error: " << error->what() << std::endl;
            }
        }
    } catch (boost::exception const& e) {
        std::cerr << "parseAndAnalyze threw boost exception: " << boost::diagnostic_information(e) << std::endl;
        std::cerr << "compiler state at crash: " << compiler.state() << std::endl;
        for (auto const& error : compiler.errors()) {
            std::cerr << "  error: " << error->what() << std::endl;
        }
    } catch (std::exception const& e) {
        std::cerr << "parseAndAnalyze threw: " << e.what() << std::endl;
    }
}
