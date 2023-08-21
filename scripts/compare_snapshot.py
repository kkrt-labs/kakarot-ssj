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
