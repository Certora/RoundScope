# wala-solidity

This repo is a WALA-based  Solidity analysis framework.

Its first bundled analysis, `RoundAbout`, takes a Certora `.conf` file and generates a report of the rounding behavior (up, down, either) of variables and functions in the referenced Solidity code.

## ⚠️ Status

- This project is under early beta testing and is still being actively developed.
- The recommended and supported workflow is the JSON-AST path described below.
- Current builds depend on a WALA fork and on Maven artifacts published locally from that build.
- Running the supported workflow also requires Certora tooling access, since `certoraRun` is used to dump ASTs.

## Overview

Currently, `RoundAbout` is the main analysis in this repository. To run it, you must have a [Certora `.conf` file](https://docs.certora.com/en/latest/docs/prover/cli/conf-file-api.html) for your project.

For most users, use the JSON-AST workflow.

## Quickstart

The fastest supported path is the JSON-AST workflow.

#### Exact Prerequisites
- Java 21
- Maven
- `certoraRun`
- A Certora project with a `.conf` file
- Access to Certora tooling for the supported workflow, since `certoraRun` is used to dump ASTs
- A local build of our WALA fork, published to your local Maven repository

#### Fastest Path To A First Successful Run
1. Clone [our fork of WALA](https://github.com/julian-certora/WALA), check out `fixesToNativeBridge`, then run `./gradlew assemble` and `./gradlew publishToMavenLocal`.
2. Clone this repository, `cd` into it, and run `mvn -DskipTests package`.
3. In the directory containing your Certora `.conf` file, run `certoraRun <conf-file> --dump_asts --compilation_steps_only`.
4. In that same directory, run:
```
java -jar /path/to/wala-solidity/target/roundabout-0.0.1-SNAPSHOT.jar <conf-file> roundabout-output.json --combined .certora_internal/latest/.asts.json
```

This writes the RoundAbout report to `roundabout-output.json`.

## Installation

We recommend following the JSON-AST workflow. Current builds depend on a WALA fork and on Maven artifacts published locally from that build. For the JSON-AST path, you can skip the native prerequisites and only install the WALA dependency described below.

#### Prerequisites
1. WALA: Clone [our fork of WALA](https://github.com/julian-certora/WALA) into some dir and checkout the `fixesToNativeBridge` branch, hereinafter called `WALA`.
2. In that directory, build using `./gradlew assemble` followed by `./gradlew publishToMavenLocal`.  If the build is too slow or dies, try `./gradlew publishToMavenLocal -xtest`. 

#### Steps
1. Clone this repository into some directory, hereinafter called `WS`
2. Ensure the `WALA` artifacts above have been published to your local Maven repository

`test/data` is used by the test suite and points to a private internal repository. It is not required for building or using the main JSON-AST workflow.

#### JSON-AST Compilation
1. make sure that your `WALA` build was successful in the previous step.
2. `cd WS`
3. run `mvn install` or `mvn -DskipTests package` if you want to skip tests. A clean install would require `mvn clean package -DskipTests`.

## Usage

### JSON-AST Workflow
The commands below describe the supported user workflow. The top-level `roundabout.sh` helper is mainly used during testing and debugging.

1. run `certoraRun` as you usually would given a `.conf` file, but add `--dump_asts --compilation_steps_only`. This will create `.certora_internal/latest/.asts.json`
2. _In the same directory_, run `RoundAbout` as
```
java -jar /path/to/roundabout-0.0.1-SNAPSHOT.jar <a .conf file> <a json output filename> --combined .certora_internal/latest/.asts.json
```
NOTE: You must run in the same directory, since the `absolutePath` properties in the JSON AST dump are often, in fact, relative paths starting with `.`

## Output Format

### RoundAbout Report Format

The report format is an array of [JGF](https://jsongraphformat.info/) graphs, one for each external or public function in the Solidity files specified by the `.conf` file.  The nodes are a refinement of the underlying call graph, with a node for each call graph node and the rounding state of its arguments.  Potentially, the same function could be called with different rounding states for its arguments, so there would be multiple nodes in this JFG graph corresponding to those multiple rounding argument states.  The graph is per-public-function so that someone interested in a specific public function sees a graph specific to that function.

More specifically, the format is as follows in terms of JSON structure, following the [JGF schema](https://github.com/jsongraph/json-graph-specification/blob/master/json-graph-schema_v2.json):
```
{ "graphs": [
  'array of rounding information per external contract function as JGF graphs'
  {
    "directed": true, (required by JGF format)
    "label": string('name of public function')
    "nodes": 'dictionary indexed by node ids (numbers as strings)'
    {
      'id 0 is the entry point'
      id: {
        "label": string('name of method')
        "metadata": {
         "methodPosition": string('file name:[sl,sc-el,ec]')
         "return": string('rounding of return value')
         "parameters": 'array of info per function parameter'
	       [
	         {
	           "rounding": string('rounding of parameter')
               "position": string('position of parameter as [sl,sc-el,ec]')
               "source": string('source code of parameter declaration')
             }
           ]
          'rounding of expressions in function'
          "roundings": {
            'id is the source position of an expression, as [sl,sc-el,ec]'
            id: {
             "rounding": string('rounding of expression')
             "source": string('source code of expression')
             "expr": string('source code of surrounding expression, if any')
           }
         }
       }
      }
    }
    "edges": 'array of edges representing calls between function in nodes'
    [
      {
        "source": caller node id
        "target": callee node id
        "label": string('call site as filename:[sl,sc-el,ec]')
      }
    ]
  }
]}
```
Note that `[sl,sc-el,ec]` means a source code position as a string, written as a left square bracket, the starting line, the starting column, a hyphen, the ending line, the ending column, and a right square bracket. Filenames are interpreted relative to the `.conf` file being analyzed.


## Repository Overview

At the top level, `pom.xml` defines the Maven build, and `roundabout.sh` is a helper script used during testing and debugging of the JSON-AST workflow.

- `roundAbout/`: `RoundAbout`-specific Java sources. This contains the main entrypoint plus the rounding analysis implementation and the JSON/JNI analysis engines used by the packaged tool.
- `src/`: shared Java source for the Solidity frontend and WALA integration, including JSON/JNI loaders, AST translation, call graph support, type models, and analysis utilities.
- `jni/`: optional native bridge for the JNI workflow. It contains the C++ bridge code, JNI headers, and the `Makefile` used to build `libwalacastsolidity.jnilib` against local Solidity and WALA builds.
- `test/src/`: JUnit test sources for the JSON-AST and JNI paths.
- `test/data/`: test fixtures used by the suite. This is a submodule containing Solidity projects, Certora `.conf` files, specs, and pre-generated AST artifacts.
- `viewer/`: Python tooling for turning RoundAbout JSON output into a self-contained HTML viewer, along with tests and golden files for that viewer.
- `scripts/`: helper scripts for development tasks around the native bridge, such as generating JNI headers and related stubs.
- `libs/`: in-repo Maven repository for local jar dependencies referenced by `pom.xml`.

## (Experimental) Advanced Users: JNI / Native Path
A native JNI-based workflow is available, but it is more experimental.
This lets you compile to use the JNI code that invokes the Solidity compiler after building it from source. This path is more complex and is mainly useful for advanced users and debugging.

### Native Prerequisites
1. C++ needs to support `-std=c++23`, so it must be a reasonably recent version.
2. The `make` or `gmake` command needs to be a recent version of GNU Make. (On the Mac using [Homebrew](https://brew.sh/), `brew install make` if GNU Make is not standard)
3. (optional) cpptrace:
A utility to generate Java-like stack traces in C++. Used in `RoundAbout` development, this has greatly eased debugging. On the Mac using [Homebrew](https://brew.sh/), a simple way to get this is `brew install cpptrace`. To avoid using this, comment out `RS_FLAGS` and `RS_DEVEL_LIBS` in the Makefile.
4. Solidity:
[build the latest Solidity from source](https://docs.soliditylang.org/en/latest/installing-solidity.html#building-from-source) in some dir, hereinafter called SOLIDITY.  We need the libraries and the include files.
5. WALA:
  Clone [our fork of WALA](https://github.com/julian-certora/WALA) into some dir and checkout the `fixesToNativeBridge` branch, hereinafter called WALA.  In that directory, build using `./gradlew assemble` followed by `./gradlew publishToMavenLocal`.  If the build is too slow or dies, try `./gradlew publishToMavenLocal -xtest`. 

### Native Compilation
1. cd `WS/jni`
2. edit the Makefile: set `WALA` and `SOLIDITY` to the values chosen above.  Set `JAVA` to be the JDK home of a recent Java version.
3. if not using `cpptrace`, then comment out `RS_FLAGS` and `RS_DEVEL_LIBS`
4. run `make`

### Native Usage
1. cd into `WS/jni`
2. `java -Djava.library.path=. -jar ../target/roundabout-0.0.1-SNAPSHOT.jar <a .conf file> filename.json` where the second argument is a json file where the results will be written.


## Contact

For questions about this repository or `RoundAbout`, please contact Julian Dolby (`julian@certora.com`) or Chandrakana Nandi (`chandra@certora.com`).
