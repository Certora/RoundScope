
JAVA=/Library/Java/JavaVirtualMachines/microsoft-21.jdk/Contents/Home
JNI_INCLUDE=$(JAVA)/include
JNI_MD_INCLUDE=$(JAVA)/include/darwin

JNI_HEADERS=$(JNI_INCLUDE)/jni.h $(JNI_MD_INCLUDE)/jni_md.h

SOLIDITY=/Users/julian/git/os
SOLIDITY_DEPS=deps/range-v3 deps/nlohmann-json deps/fmtlib
SOLIDITY_DIRS=libevmasm liblangutil libsmtutil libsolc libsolidity libsolutil libyul 
SOLIDITY_INCLUDES=-I$(SOLIDITY) $(foreach dep,$(SOLIDITY_DEPS),-I$(SOLIDITY)/$(dep)/include)
SOLIDITY_LIB_DIRS=$(foreach dir,$(SOLIDITY_DIRS),-L$(SOLIDITY)/build/$(dir))
SOLIDITY_LIBS=$(foreach dir,$(SOLIDITY_DIRS),$(patsubst lib%,-l%,$(dir)))

BREW_INCLUDES=-I/opt/homebrew/include

BOOST_LIB_DIRS=-L/opt/homebrew/lib
BOOST_LIBS=-lboost_filesystem

WALA=/Users/julian/git/WALA
CAST=$(WALA)/cast
CAST_INCLUDES=-I$(CAST)/cast/src/main/public
CAST_LIB_DIRS=-L$(CAST)/cast/build/lib/main/debug -Wl,-rpath,$(CAST)/cast/build/lib/main/debug
CAST_LIBS=-lcast

default:	libwalacastsolidity.jnilib

com_certora_wala_cast_solidity_jni_SolidityJNIBridge.o:	com_certora_wala_cast_solidity_jni_SolidityJNIBridge.h com_certora_wala_cast_solidity_jni_SolidityJNIBridge.cpp $(JNI_HEADERS)
	$(CC) -std=c++23 -fpic -c -o $@ -I$(JNI_INCLUDE) -I$(JNI_MD_INCLUDE) $(SOLIDITY_INCLUDES) $(BREW_INCLUDES) $(CAST_INCLUDES) com_certora_wala_cast_solidity_jni_SolidityJNIBridge.cpp

solidityBridge.o:	solidityBridge.h solidityBridge.cpp
	$(CC) -std=c++23 -fpic -c -o $@ $(SOLIDITY_INCLUDES) $(BREW_INCLUDES) solidityBridge.cpp

translator.o:	solidityBridge.h translator.h translator.cpp
	$(CC) -std=c++23 -fpic -c -o $@ $(SOLIDITY_INCLUDES) $(BREW_INCLUDES)  $(CAST_INCLUDES) -I$(JNI_INCLUDE) -I$(JNI_MD_INCLUDE) translator.cpp

libwalacastsolidity.jnilib:	com_certora_wala_cast_solidity_jni_SolidityJNIBridge.o solidityBridge.o translator.o
	$(CC) -dynamiclib -o $@ $^ $(SOLIDITY_LIB_DIRS) $(BOOST_LIB_DIRS) $(CAST_LIB_DIRS) $(SOLIDITY_LIBS) $(BOOST_LIBS) $(CAST_LIBS) -lcpptrace -lstdc++ 

clean:
	rm libwalacastsolidity.jnilib *.o
