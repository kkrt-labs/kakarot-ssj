import json
import os
import re
import subprocess


def get_github_token_from_env(file_path=".env"):
    """Read the .env file and extract the GITHUB_TOKEN value."""
    try:
        with open(file_path, "r") as file:
            for line in file:
                if line.startswith("#"):
                    continue
                key, value = line.strip().split("=", 1)
                if key == "GITHUB_TOKEN":
                    return value
    except FileNotFoundError:
        return None
    except ValueError:
        print(f"Error: Invalid format in {file_path}. Expected 'KEY=VALUE' format.")
    return None


def get_previous_snapshot():
    REPO = "kkrt-labs/kakarot-ssj"  # Replace with your GitHub username and repo name
    GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", get_github_token_from_env())
    if GITHUB_TOKEN is None:
        raise ValueError(
            "GITHUB_TOKEN doesn't exist in current shell nor is defined .env"
        )

    try:
        # Fetch the list of workflow runs
        cmd = f"curl -s -H 'Authorization: token {GITHUB_TOKEN}' -H 'Accept: application/vnd.github.v3+json' 'https://api.github.com/repos/{REPO}/actions/runs?branch=main&per_page=100'"
        result = subprocess.check_output(cmd, shell=True)
        runs = json.loads(result)

        # Find the latest successful run
        latest_successful_run = next(
            (
                run
                for run in runs["workflow_runs"]
                if run["conclusion"] == "success"
                and run["name"] == "Generate and Upload Gas Snapshot"
            ),
            None,
        )

        # Fetch the artifacts for that run
        run_id = latest_successful_run["id"]
        cmd = f"curl -s -H 'Authorization: token {GITHUB_TOKEN}' -H 'Accept: application/vnd.github.v3+json' 'https://api.github.com/repos/{REPO}/actions/runs/{run_id}/artifacts'"
        result = subprocess.check_output(cmd, shell=True)
        artifacts = json.loads(result)

        # Find the gas_snapshot.json artifact
        snapshot_artifact = next(
            artifact
            for artifact in artifacts["artifacts"]
            if artifact["name"] == "gas-snapshot"
        )

        # Download the gas_snapshots.json archive
        archive_name = "gas_snapshot.zip"
        json_name = "gas_snapshot.json"
        cmd = f"curl -s -L -o {archive_name} -H 'Authorization: token {GITHUB_TOKEN}' -H 'Accept: application/vnd.github.v3+json' '{snapshot_artifact['archive_download_url']}'"
        subprocess.check_call(cmd, shell=True)

        # Extract the archive to get gas_snapshots.json using the unzip command
        cmd = f"unzip -o {archive_name}"  # -o option is to overwrite files without prompting
        subprocess.check_call(cmd, shell=True)

        with open(json_name, "r") as f:
            # Load and return the snapshot data
            text = f.read()

        os.remove(json_name)
        os.remove(archive_name)
        return json.loads(text)
    except subprocess.CalledProcessError:
        print("Error: Failed to execute a subprocess command.")
    except StopIteration:
        print("Error: Couldn't find the desired workflow run or artifact.")
    except FileNotFoundError:
        print("Error: Couldn't find the gas_snapshot.json file after download.")
    except json.JSONDecodeError:
        print("Error: Failed to parse JSON data.")

    return {}


def get_current_gas_snapshot():
    """Execute command and return current gas snapshots."""
    output = subprocess.check_output("scarb cairo-test", shell=True).decode("utf-8")
    pattern = r"test (.+?) \.\.\. ok \(gas usage est.: (\d+)\)"
    matches = re.findall(pattern, output)
    matches.sort()
    return {match[0]: int(match[1]) for match in matches}


def compare_snapshots(current, previous):
    """Compare current and previous snapshots and return differences."""
    worsened = []
    improvements = []
    common_keys = set(current.keys()) & set(previous.keys())

    for key in common_keys:
        prev = previous[key]
        cur = current[key]
        percentage_change = (cur - prev) * 100 / prev
        if prev < cur:
            worsened.append(
                f"{key} {prev} --> {cur} {format(percentage_change, '.2f')} %"
            )
        elif prev > cur:
            improvements.append(
                f"{key} {prev} --> {cur} {format(percentage_change, '.2f')} %"
            )

    return improvements, worsened


def print_formatted_output(improvements, worsened, gas_changes):
    """Print results formatted."""
    if improvements or worsened:
        print("****IMPROVEMENTS****")
        for elem in improvements:
            print(elem)

        print("\n")
        print("****WORSENED****")
        for elem in worsened:
            print(elem)

        gas_statement = (
            "performance degradation, gas consumption +"
            if gas_changes > 0
            else "performance improvement, gas consumption"
        )
        print(f"Overall gas change: {gas_statement}{format(gas_changes, '.2f')} %")
    else:
        print("No changes in gas consumption.")


def total_gas_used(current, previous):
    """Return the total gas used in the current and previous snapshot, not taking into account added tests."""
    common_keys = set(current.keys()) & set(previous.keys())

    cur_gas = sum(current[key] for key in common_keys)
    prev_gas = sum(previous[key] for key in common_keys)

    return cur_gas, prev_gas


def main():
    """Main function to execute the snapshot test framework."""
    # Load previous snapshot
    previous_snapshot = get_previous_snapshot()
    if previous_snapshot == {}:
        print("Error: Failed to load previous snapshot.")
        return

    current_snapshots = get_current_gas_snapshot()
    improvements, worsened = compare_snapshots(current_snapshots, previous_snapshot)
    cur_gas, prev_gas = total_gas_used(current_snapshots, previous_snapshot)
    print_formatted_output(
        improvements, worsened, (cur_gas - prev_gas) * 100 / prev_gas
    )
    if worsened:
        raise ValueError("Gas usage increased")


if __name__ == "__main__":
    main()
