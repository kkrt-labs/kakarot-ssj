#!/bin/bash

# Run the scarb metadata command and store the JSON output in a variable
json_output=$(scarb metadata --format-version 1| sed -n '/^{/,$p')

# Create a temporary file to store the JSON output
temp_file=$(mktemp)
echo "$json_output" > "$temp_file"

# Run the NodeJS script to process the JSON output and create the cairo_project.toml file
node -e "
  const fs = require('fs');
  const path = require('path');

  const jsonFile = '$temp_file';
  const rawData = fs.readFileSync(jsonFile, 'utf-8');
  const jsonData = JSON.parse(rawData);

  const packagesData = jsonData.packages;
  const crateRoots = {};

  packagesData.forEach(component => {
    const sourcePath = component.root+\"\/src\";
    const name = component.name;
    if (name != \"core\"){
        crateRoots[name] = sourcePath;
    }
  });

  let cairoProjectToml = '[crate_roots]\n';

  for (const [key, value] of Object.entries(crateRoots)) {
    cairoProjectToml += key + ' = \"' + value + '\"\n';
  }
    cairoProjectToml += 'tests = \"tests\"';

  fs.writeFileSync('cairo_project.toml', cairoProjectToml);
"

# Remove the temporary file
rm "$temp_file"
