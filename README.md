# RoundScope - rounding analysis for Solidity

This tool takes a Certora `.conf` file, and performs analysis to generate a report of the rounding behavior (up, down, either) of variables and functions in the Solidity code that is specified in the `.conf` file.

## report format

The report formay is a [JGF](https://jsongraphformat.info/) array of graphs, one for each external or public function in the Solidity files specified by the `.conf` file.  The nodes are a refinement of the underlying call graph, with a node for each call graph node and the rounding state of its arguments.  Potentially, the same function could be called with different rounding states for its arguments, so there would be multiple nodes in this JFG graph corresponding to those multiple rounding argument states.  The graph is per-public-function so that someone interested in a specific public function sees a graph specific to that function.

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
Note that `[sl,sc-el,ec]` means a source code position as a string, written as a left square brace, the starting line, the starting column, a hyphen, the ending line, the ending column, a right square brace.  Filenames are in terms of the `.conf` file.

## building the code

### RoundScope has some prerequisites that need to be installed first:
1. C++ needs to support `-std=c++23`, so it must be a reasonably recent version.
2. The `make` or `gmake` command needs to be a recent version of GNU Make. (On the Mac using [Homebrew](https://brew.sh/), `brew install make` if GNU Make is not standard)
3. (optional) cpptrace:
A utility to generate Java-like stack traces in C++.  Used in RoundScope development, this has greatly eased debugging for me.  On the Mac using [Homebrew](https://brew.sh/), a simple way to get this is `brew install cpptrace`.  To avoid using this, comment out RS_FLAGS and RS_DEVEL_LIBS in the Makefile.
4. Solidity:
[build the latest Solidity from source](https://docs.soliditylang.org/en/latest/installing-solidity.html#building-from-source) in some dir, hereinafter called SOLIDITY.  We need the libraries and the include files.
5. WALA:
While we evaluate this approach, we need to use my version of WALA with minor fixes to its native code support.   These changes can all be folded into the main WALA repository in due course.  Clone [my WALA](https://github.com/julian-certora/WALA) into some dir, hereinafter called WALA.  In that directory, build using `./gradlew publishToMavenLocal`.  If the build is too slow or dies, try `./gradlew publishToMavenLocal -xtest`

### building RoundScope
1. Get RoundScope: clone this repository into some dir, hereinafter called `RS`
   
2. building the Java code
   1. `cd RS`
   2. run `maven install`

4. building the native code
   1. cd `RS/WALA CAst Solidity JNI Bridge`
   2. edit the Makefile: set `WALA` and `SOLIDITY` to the values chosen above.  Set `JAVA` to be the JDK home of a recent Java version.
   3. if not using `cpptrace`, then comment out `RS_FLAGS` and `RS_DEVEL_LIBS`
   4. run `make`

### Running RoundScope
1. cd into `RS/WALA CAst Solidity JNI Bridge`
2. ```java -Djava.library.path=. -jar ../target/com.certora.RoundScope-0.0.1-SNAPSHOT.jar <a .conf file>`
