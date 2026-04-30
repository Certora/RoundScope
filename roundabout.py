#!/usr/bin/env python3
"""Core RoundAbout pipeline: dump ASTs via certoraRun, then run the Java analysis."""

import argparse
import json
import json5
import os
import shutil
import subprocess
import sys
import tempfile

DOCKER_IMAGE = "ghcr.io/certora/roundabout:latest"


def main():
    parser = argparse.ArgumentParser(
        description="Run the RoundAbout AST-dump and analysis pipeline."
    )
    parser.add_argument(
        "--certora-run-command",
        default="certoraRun",
        help="Command to use instead of certoraRun (default: certoraRun)",
    )
    parser.add_argument(
        "--docker",
        action="store_true",
        help=argparse.SUPPRESS,
    )
    parser.add_argument("project_root", help="Project root directory")
    parser.add_argument("input_file", help="Path to a .conf or .sol file")
    parser.add_argument("output_json", help="Path for the output JSON")
    args = parser.parse_args()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    jar = os.path.join(script_dir, "target", "roundabout-0.0.1-SNAPSHOT.jar")

    project_dir = os.path.abspath(args.project_root)
    input_file = args.input_file
    output = args.output_json

    os.chdir(project_dir)
    print(f"[roundabout] project_dir: {project_dir}")
    print(f"[roundabout] input_file:  {input_file}")
    print(f"[roundabout] output:      {output}")
    print(f"[roundabout] cwd:         {os.getcwd()}")

    # If .sol file, generate temporary conf and spec
    temp_files = []
    try:
        if input_file.endswith(".sol"):
            contract_name = os.path.splitext(os.path.basename(input_file))[0]
            base = os.path.splitext(input_file)[0]

            fd_spec, temp_spec = tempfile.mkstemp(suffix=".spec", prefix=f"{contract_name}_", dir=os.path.dirname(base) or ".")
            with os.fdopen(fd_spec, "w") as f:
                f.write("rule trivial { assert true; }\n")
            temp_files.append(temp_spec)

            fd_conf, temp_conf = tempfile.mkstemp(suffix=".conf", prefix=f"{contract_name}_", dir=os.path.dirname(base) or ".")
            with os.fdopen(fd_conf, "w") as f:
                json.dump({"files": [input_file], "verify": f"{contract_name}:{temp_spec}"}, f, indent=4)
            temp_files.append(temp_conf)

            conf = temp_conf
            print(f"Generated temporary conf and spec for {input_file}")
        elif input_file.endswith(".conf"):
            conf = input_file
        else:
            print("Error: Input file must be a .conf or .sol file.", file=sys.stderr)
            sys.exit(1)

        # Parse conf to decide flags
        print(f"[roundabout] parsing conf: {conf}")
        try:
            with open(conf) as f:
                conf_data = json5.load(f)
        except Exception as e:
            print(f"Error: Failed to parse conf file {conf}: {e}", file=sys.stderr)
            sys.exit(1)
        print(f"[roundabout] conf keys: {list(conf_data.keys())}")
        print(f"[roundabout] conf 'files': {conf_data.get('files', 'NOT SET')}")
        print(f"[roundabout] conf 'verify': {conf_data.get('verify', 'NOT SET')}")
        if "override_base_config" in conf_data:
            print(f"[roundabout] override_base_config: {conf_data['override_base_config']}")

        # Resolve override_base_config inheritance
        if "override_base_config" in conf_data:
            try:
                with open(conf_data["override_base_config"]) as f:
                    base_data = json5.load(f)
                base_data.update(conf_data)
                conf_data = base_data
            except Exception:
                pass  # If base can't be loaded, proceed with what we have

        extra_flags = ["--disable_local_typechecking", "--ignore_solidity_warnings"]
        if "assert_autofinder_success" not in conf_data:
            extra_flags.append("--disable_internal_function_instrumentation")
        print(f"[roundabout] extra_flags: {extra_flags}")

        # Create dummy spec and temp conf for certoraRun AST dump
        verify = conf_data.get("verify", "")
        contract_name = verify.split(":")[0] if ":" in verify else "Unknown"

        fd_spec, temp_spec = tempfile.mkstemp(suffix=".spec", prefix="roundabout_")
        with os.fdopen(fd_spec, "w") as f:
            f.write("rule trivial { assert true; }\n")
        temp_files.append(temp_spec)

        dump_conf_data = dict(conf_data)
        dump_conf_data["verify"] = f"{contract_name}:{temp_spec}"
        fd_conf, dump_conf = tempfile.mkstemp(suffix=".conf", prefix="roundabout_")
        with os.fdopen(fd_conf, "w") as f:
            json.dump(dump_conf_data, f, indent=4)
        temp_files.append(dump_conf)
        print(f"[roundabout] contract_name: {contract_name}")
        print(f"[roundabout] dump_conf: {dump_conf}")
        print(f"[roundabout] dump_conf contents:")
        print(json.dumps(dump_conf_data, indent=2))

        # Record timestamp before running certoraRun
        fd_ts, timestamp_ref = tempfile.mkstemp()
        os.close(fd_ts)

        cmd = [args.certora_run_command, dump_conf, "--dump_asts", "--build_only"] + extra_flags
        print(f"[roundabout] certoraRun command: {' '.join(cmd)}")
        print(f"[roundabout] running certoraRun...")
        result_certora = subprocess.run(cmd, capture_output=True, text=True)
        print(f"[roundabout] certoraRun exit code: {result_certora.returncode}")
        if result_certora.stdout:
            print(f"[roundabout] certoraRun stdout:\n{result_certora.stdout}")
        if result_certora.stderr:
            print(f"[roundabout] certoraRun stderr:\n{result_certora.stderr}")

        asts_file = ".certora_internal/latest/.asts.json"
        print(f"[roundabout] checking for asts_file: {os.path.abspath(asts_file)}")
        print(f"[roundabout] asts_file exists: {os.path.isfile(asts_file)}")
        if os.path.isfile(asts_file):
            import stat
            st = os.stat(asts_file)
            print(f"[roundabout] asts_file size: {st.st_size} bytes, mtime: {st.st_mtime}")
        if not os.path.isfile(asts_file) or os.path.getmtime(asts_file) < os.path.getmtime(timestamp_ref):
            os.unlink(timestamp_ref)
            print(f"Error: {asts_file} not found or not updated by certoraRun.", file=sys.stderr)
            sys.exit(1)
        os.unlink(timestamp_ref)

        print("[roundabout] running RoundAbout Java analysis...")
        use_docker = args.docker or not shutil.which("java")
        print(f"[roundabout] use_docker: {use_docker}, java found: {shutil.which('java') is not None}")
        if not use_docker:
            java_cmd = ["java", "-jar", jar, conf, output, "--combined", asts_file]
            print(f"[roundabout] java command: {' '.join(java_cmd)}")
            sys.stdout.flush()
            sys.stderr.flush()
            result = subprocess.run(java_cmd)
        elif shutil.which("docker"):
            if not shutil.which("java"):
                print("Java not found, running via Docker...")
            else:
                print("Running via Docker...")
            sys.stdout.flush()
            sys.stderr.flush()
            result = subprocess.run([
                "docker", "run", "--rm",
                "-v", f"{project_dir}:{project_dir}",
                "-w", project_dir,
                DOCKER_IMAGE,
                conf, output, "--combined", asts_file,
            ])
        else:
            print(
                "Error: Neither Java nor Docker found.\n"
                "Please install one of:\n"
                "  - Java 21+: https://adoptium.net/\n"
                "  - Docker:   https://docs.docker.com/get-docker/",
                file=sys.stderr,
            )
            sys.exit(1)
        print(f"[roundabout] Java analysis exit code: {result.returncode}")
        if result.returncode != 0:
            print("Error: RoundAbout analysis failed.", file=sys.stderr)
            sys.exit(result.returncode)
        print(f"[roundabout] output JSON written to: {output}")
        if os.path.isfile(output):
            print(f"[roundabout] output JSON size: {os.path.getsize(output)} bytes")
    finally:
        for f in temp_files:
            if os.path.exists(f):
                os.unlink(f)


if __name__ == "__main__":
    main()
