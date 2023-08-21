import subprocess
import re
import json

# Execute the command and capture the output
output = subprocess.check_output("scarb cairo-test", shell=True).decode('utf-8')

# Use regex to capture test names and their associated gas usage
pattern = r"test (.+?) \.\.\. ok \(gas usage est.: (\d+)\)"
matches = re.findall(pattern, output)

# Convert matches to a dictionary
results = {match[0]: int(match[1]) for match in matches}
sorted_results = {k: results[k] for k in sorted(results.keys())}

# Dump the results to a JSON file
with open("gas_snapshots.json", "w") as outfile:
    json.dump(sorted_results, outfile, indent=4)
