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
        try:
            with open(conf) as f:
                conf_data = json5.load(f)
        except Exception as e:
            print(f"Error: Failed to parse conf file {conf}: {e}", file=sys.stderr)
            sys.exit(1)

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

        # Record timestamp before running certoraRun
        fd_ts, timestamp_ref = tempfile.mkstemp()
        os.close(fd_ts)

        print(f"Running {args.certora_run_command} to dump ASTs...")
        cmd = [args.certora_run_command, dump_conf, "--dump_asts", "--build_only"] + extra_flags
        subprocess.run(cmd)

        asts_file = ".certora_internal/latest/.asts.json"
        if not os.path.isfile(asts_file) or os.path.getmtime(asts_file) < os.path.getmtime(timestamp_ref):
            os.unlink(timestamp_ref)
            print(f"Error: {asts_file} not found or not updated by certoraRun.", file=sys.stderr)
            sys.exit(1)
        os.unlink(timestamp_ref)

        print("Running RoundAbout analysis...")
        use_docker = args.docker or not shutil.which("java")
        if not use_docker:
            result = subprocess.run(
                ["java", "-jar", jar, conf, output, "--combined", asts_file],
            )
        elif shutil.which("docker"):
            if not shutil.which("java"):
                print("Java not found, running via Docker...")
            else:
                print("Running via Docker...")
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
        if result.returncode != 0:
            print("Error: RoundAbout analysis failed.", file=sys.stderr)
            sys.exit(result.returncode)
    finally:
        for f in temp_files:
            if os.path.exists(f):
                os.unlink(f)


if __name__ == "__main__":
    main()
