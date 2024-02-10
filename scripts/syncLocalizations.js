// SPDX-License-Identifier: ice License 1.0

const fs = require('fs');

function deepMerge(target, source) {
  for (const [key, value] of Object.entries(source)) {
    if (Object.prototype.hasOwnProperty.call(source, key)) {
      if (target[key] && typeof target[key] === 'object' && typeof value === 'object') {
        deepMerge(target[key], value);
      } else {
        target[key] = value;
      }
    }
  }
}

function ensureValidJsonFile(filePath) {
  try {
    if (!fs.existsSync(filePath)) {
      fs.writeFileSync(filePath, '{}');
    }
  } catch (error) {
    console.error(`Error while ensuring valid JSON file at ${filePath}: ${error.message}`);
  }
}

function checkAndAddNewline(filePath) {
  try {
    const fileContents = fs.readFileSync(filePath, 'utf8');
    if (!fileContents.endsWith('\n')) {
      fs.appendFileSync(filePath, '\n');
    }
  } catch (error) {
    console.error(`Error while checking and adding newline in file at ${filePath}: ${error.message}`);
  }
}

function updateJsonFiles(newJsonPath, jsonFilesDirectory) {
  try {
    if (!fs.existsSync(newJsonPath)) {
      throw new Error(`Error: new.json does not exist at ${newJsonPath}`);
    }

    if (!fs.statSync(jsonFilesDirectory).isDirectory()) {
      throw new Error(`Error: Directory does not exist at ${jsonFilesDirectory}`);
    }

    const newJson = JSON.parse(fs.readFileSync(newJsonPath, 'utf8'));

    fs.readdirSync(jsonFilesDirectory).forEach(file => {
      if (file.endsWith('.json')) {
        const jsonFilePath = path.resolve(jsonFilesDirectory, file);
        const languageCode = path.basename(file, '.json');
        ensureValidJsonFile(jsonFilePath);
        const value = newJson[languageCode] || newJson[`${newJson[languageCode]}.json`];
        if (value) {
          let existingJson = {};
          try {
            existingJson = JSON.parse(fs.readFileSync(jsonFilePath, 'utf8') || '{}');
          } catch (error) {
            console.error(`Error while parsing JSON file at ${jsonFilePath}: ${error.message}`);
          }
          deepMerge(existingJson, value);

          try {
            fs.writeFileSync(jsonFilePath, JSON.stringify(existingJson, null, 2) + '\n');
            checkAndAddNewline(jsonFilePath);
          } catch (error) {
            console.error(`Error while writing JSON file at ${jsonFilePath}: ${error.message}`);
          }
        }
      }
    });

    console.log('JSON files updated successfully.');
  } catch (error) {
    console.error(`Error: ${error.message}`);
  }
}

// Example usage: node syncLocalizations.js <path_to_new.json> <path_to_json_files_directory>
const args = process.argv.slice(2);

if (args.length !== 2) {
  console.log('Usage: node syncLocalizations.js <path_to_new.json> <path_to_json_files_directory>');
} else {
  const newJsonPath = args[0];
  const jsonFilesDirectory = args[1];
  updateJsonFiles(newJsonPath, jsonFilesDirectory);
}
