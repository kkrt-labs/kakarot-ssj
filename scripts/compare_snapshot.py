import subprocess
import re
import json

# ANSI escape codes for coloring text
GREEN = '\033[92m'
RED = '\033[91m'
ENDC = '\033[0m'

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
        prev = previous[key]
        cur = current[key]
        if prev < cur:
            worsened.append(f"{key} {prev} --> {cur} {(cur - prev)*100/prev} %")
        elif prev > cur:
            improvements.append(f"{key} {prev} --> {cur} | {(cur - prev)*100/prev} %"  )
    
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
        
        color = GREEN if gas_changes > 0 else RED
        print(color + f"Overall gas change: {gas_changes} %" + ENDC)

        exit(1)

def total_gas_used(current,previous):
    """Return the total gas used in the current and previous snapshot."""
    return sum(current.values()), sum(previous.values())

def main():
    """Main function to execute the snapshot test framework."""
    # Load previous snapshot
    with open("gas_snapshots.json", "r") as f:
        previous_snapshot = json.load(f)
    
    current_snapshots = get_current_gas_snapshots()
    improvements, worsened = compare_snapshots(current_snapshots, previous_snapshot)
    cur_gas, prev_gas = total_gas_used(current_snapshots, previous_snapshot)
    print_colored_output(improvements, worsened, (cur_gas-prev_gas)*100/prev_gas)

if __name__ == "__main__":
    main()
