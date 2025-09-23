import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

#### --- GLOBAL ---- ####
header_lines = []
recap_lines = []
table_lines = []
num_above_threshold = 0
# Enumerates icons to be displayed for each severity level
icons = {
    1: "⚫",
    2: "🔴",
    3: "🟠",
    4: "🟡",
    5: "⚪",
}
# Describes each severity level
severity_descriptions = {1: "Critical", 2: "High", 3: "Medium", 4: "Low", 5: "Info"}
# Counts the number of violations by severity level
violations_count = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}

#### --- HELPER ---- ####
def build_header(violations, threshold):
    # Build the .md file's header:
    if num_above_threshold == 0:
        header_lines.append("<h3>✅ Static Analysis: Check Passed</h3>")
    else:
        header_lines.append("<h3>🚨 Static Analysis: Check Failed</h3>")
    threshold_description = severity_descriptions.get(threshold)
    header_lines.append(
        f"Analyzed changed files, and found {len(violations)} potential violations. "
        f"{num_above_threshold} meets or exceeds the set severity threshold: "
        f"<code>{threshold_description}</code><br/>"
    )


def build_recap():
    # Build a blockquoted recap section:
    recap_lines.append("<br/><blockquote>")
    for key in violations_count:
        icon = icons.get(key, ":white_circle:")
        num = violations_count.get(key, 0)
        description = severity_descriptions.get(key, "N/A")
        recap_lines.append(
            f"<b>{icon} {num} {description}</b> severity violation(s)<br/>"
        )
    recap_lines.append("</blockquote>")


def build_table(violations, threshold):
    # Build an HTML table containing details about each violation:
    if len(violations) == 0:
        # Omit the table if there are no violations:
        return
    table_lines.append(
        "<table><tr><th> </th><th>Location</th><th>Rule</th><th>Message</th></tr>"
    )
    for v in violations:
        global num_above_threshold
        # Increment the counts:
        severity = v.get("severity", 5)
        violations_count[severity] += 1
        if severity <= threshold:
            num_above_threshold += 1
        # Add a row to the table:
        icon = v.get("icon")
        location = v.get("location")
        message = v.get("message")
        rule = v.get("rule")
        row = f"<tr><td>{icon}</td><td><sup>{location}</sup></td><td><sup>{rule}</sup></td><td><sup>{message}</sup></td></tr>"
        table_lines.append(row)
    table_lines.append("</table>")

def define_args():
    # Defines arguments to be used with the main program:
    parser = argparse.ArgumentParser(
        description="Run sf code-analyzer against a target directory"
    )
    parser.add_argument(
        "--results-file",
        help="Path that output variables will be saved to. This is a .txt file, for use in Github actions",
        default="results.txt",
    )
    parser.add_argument(
        "--sfca-output-file",
        help="Path that sf code analyzer's raw .json results will be saved to",
        default="sfca_results.json",
    )
    parser.add_argument(
        "--summary-file",
        help="Path that the formatted .md summary will be saved to",
        default="static_analysis_summary.md",
    )
    parser.add_argument("--target", help="The directory to scan", default="source/")
    parser.add_argument(
        "--threshold",
        help="Defines the severity threshold of violations that are allowed w/out failure",
        type=int,
        choices=[1, 2, 3, 4, 5],
        default=2,
    )
    return parser.parse_args()


def get_sfca_violation_location(violation):
    # sf code-analyzer stores location as an array, since there may be several instances of a violation
    # Join these locations into a single string, to use in the table:
    locations = []
    for l in violation.get("locations", []):
        # Note: Omit everything before the actual working directory:
        path = "source/" + l.get("file").split("source/", 1)[-1]
        start_line = l.get("startLine", "?")
        start_col = l.get("startColumn", "?")
        loc = f"{path}:{start_line}:{start_col}"
        locations.append(loc)
    return "\n".join(locations)


def run_sfca(target, output="sfca_results.json"):
    # Run sf code analyzer and return an output object that can be formatted into a table:
    cmd = ["sf", "code-analyzer", "run", "--output-file", output, "--target", target]
    print("Running sf code-analyzer...\n", " ".join(cmd))
    subprocess.run(cmd, capture_output=True, text=True, check=True)
    # Open the output file and read the results:
    with open(output) as f:
        data = json.load(f)
    # Iterate through the violations, use it to build an object:
    violations = []
    for v in data.get("violations", []):
        engine = v.get("engine")
        rule_name = v.get("rule")
        violation = {
            "icon": icons.get(v.get("severity"), ":white_circle:"),
            "location": get_sfca_violation_location(v),
            "message": v.get("message", ""),
            "reported_by": "sf code-analyzer",
            "rule": f"{engine}:{rule_name}",
            "severity": v.get("severity", 5),
        }
        violations.append(violation)
    print(f"{len(violations)} sf code-analyzer violations")
    return violations


def scan(args):
    # Run the scanning tools, and output their results in a common object format:
    all_violations = run_sfca(args.target, output=args.sfca_output_file)
    # Sort the violations by severity, in order of most to least severe
    all_violations.sort(key=lambda v: v.get("severity", 5))
    print(f"🐞 Violations: ", json.dumps(all_violations))
    return all_violations


def set_gh_outputs(results_file):
    # Set outputs to be referenced in github actions:
    outputs = [
        f"num-violations-above-threshold={num_above_threshold}",
        f"num-critical-severity-violations={violations_count.get(1)}",
        f"num-high-severity-violations={violations_count.get(2)}",
        f"num-medium-severity-violations={violations_count.get(3)}",
        f"num-low-severity-violations={violations_count.get(4)}",
        f"num-info-severity-violations={violations_count.get(5)}",
    ]
    Path(results_file).write_text("\n".join(outputs))


def summarize(violations, args):
    # Once the scans are run, iterate through violations and build a .md summary:
    build_table(violations, args.threshold)
    build_recap()
    build_header(violations, args.threshold)
    all_lines = header_lines + recap_lines + table_lines
    summary = "\n".join(all_lines)
    Path(args.summary_file).write_text(summary)


#### ---- MAIN ---- ####
if __name__ == "__main__":
    try:
        # Define the args available for this function:
        args = define_args()
        # Run the various scanning tools:
        violations = scan(args)
        # Write the completed .md to the summary file:
        summarize(violations, args)
        # Generate .txt file containing outputs for github actions:
        set_gh_outputs(args.results_file)
    except Exception as e:
        print("Error:", str(e), file=sys.stderr)
        sys.exit(1)