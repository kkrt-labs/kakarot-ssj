import subprocess
import re
import json
import os

# ANSI escape codes for coloring text
GREEN = '\033[92m'
RED = '\033[91m'
ENDC = '\033[0m'

def get_previous_snapshot():

    try:
        REPO = "kkrt-labs/kakarot-ssj"

        # Fetch the list of workflow runs
        cmd = f"curl -H 'Accept: application/vnd.github.v3+json' 'https://api.github.com/repos/{REPO}/actions/runs'"
        result = subprocess.check_output(cmd, shell=True)
        runs = json.loads(result)

        # Find the latest successful run
        latest_successful_run = next(run for run in runs["workflow_runs"] if run["conclusion"] == "success")

        # Fetch the artifacts for that run
        run_id = latest_successful_run["id"]
        cmd = f"curl -H 'Accept: application/vnd.github.v3+json' 'https://api.github.com/repos/{REPO}/actions/runs/{run_id}/artifacts'"
        result = subprocess.check_output(cmd, shell=True)
        artifacts = json.loads(result)

        # Find the gas_snapshots.json artifact
        snapshot_artifact = next(artifact for artifact in artifacts["artifacts"] if artifact["name"] == "gas-snapshot")

        # Download the gas_snapshots.json file
        cmd = f"curl -L -o gas_snapshots.json -H 'Accept: application/vnd.github.v3+json' '{snapshot_artifact['archive_download_url']}'"
        subprocess.check_call(cmd, shell=True)

        # Load and return the snapshot data
        with open("gas_snapshots.json", "r") as f:
            return json.load(f)

    except subprocess.CalledProcessError:
        print("Error: Failed to execute a subprocess command.")
    except StopIteration:
        print("Error: Couldn't find the desired workflow run or artifact.")
    except FileNotFoundError:
        print("Error: Couldn't find the gas_snapshots.json file after download.")
    except json.JSONDecodeError:
        print("Error: Failed to parse JSON data.")

    return {}


def get_current_gas_snapshots():
    """Execute command and return current gas snapshots."""
    output = subprocess.check_output("scarb cairo-test", shell=True).decode('utf-8')
    pattern = r"test (.+?) \.\.\. ok \(gas usage est.: (\d+)\)"
    matches = re.findall(pattern, output)
    matches.sort()
    return {match[0]: int(match[1]) for match in matches}

def compare_snapshots(current, previous):
    """Compare current and previous snapshots and return differences."""
    worsened = []
    improvements = []

    for key in previous:
        if key not in current:
            continue
        prev = previous[key]
        cur = current[key]
        percentage_change = (cur - prev)*100/prev
        if prev < cur:
            worsened.append(f"{key} {prev} --> {cur} {format(percentage_change, '.2f')} %")
        elif prev > cur:
            improvements.append(f"{key} {prev} --> {cur} | {format(percentage_change, '.2f')} %"  )

    return improvements, worsened

def print_colored_output(improvements, worsened, gas_changes):
    """Print results in a colored format."""
    if improvements or worsened:
        print(GREEN + "___IMPROVEMENTS___" + ENDC)
        for elem in improvements:
            print(GREEN + elem + ENDC)

        print("\n\n")
        print(RED + "___WORSENED___" + ENDC)
        for elem in worsened:
            print(RED + elem + ENDC)

        color = RED if gas_changes > 0 else GREEN
        gas_statement = "performance degradation, gas consumption +" if gas_changes > 0 else "performance improvement, gas consumption"
        print(color + f"Overall gas change: {gas_statement}{format(gas_changes, '.2f')} %" + ENDC)

def total_gas_used(current,previous):
    """Return the total gas used in the current and previous snapshot."""
    return sum(current.values()), sum(previous.values())

def main():
    """Main function to execute the snapshot test framework."""
    # Load previous snapshot
    previous_snapshot = get_previous_snapshot()
    if previous_snapshot == {}:
        print("Error: Failed to load previous snapshot.")
        return
    current_snapshots = get_current_gas_snapshots()
    improvements, worsened = compare_snapshots(current_snapshots, previous_snapshot)
    cur_gas, prev_gas = total_gas_used(current_snapshots, previous_snapshot)
    print_colored_output(improvements, worsened, (cur_gas-prev_gas)*100/prev_gas)

if __name__ == "__main__":
    main()
