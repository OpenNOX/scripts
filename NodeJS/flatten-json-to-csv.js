const fs = require('fs');
const path = require('path');
const jp = require('jsonpath');

const jsonFilePath = process.argv[2];
const jsonPathsFilePath = process.argv[3];
const jsonPaths = JSON.parse(fs.readFileSync(jsonPathsFilePath, { encoding: 'utf-8' }));
const csvFilePath = `${path.dirname(jsonFilePath)}/${path.basename(jsonFilePath, '.json')}.csv`;
const csv = fs.createWriteStream(csvFilePath, { encoding: 'utf-8' });

const headers = Object.keys(jsonPaths);
const sanitizeCsvValues = (arr) => arr.map(v => v.includes(',') ? `"${v}"` : v);

csv.write(`${sanitizeCsvValues(headers).join(',')}\n`);

JSON.parse(fs.readFileSync(jsonFilePath, { encoding: 'utf-8' })).forEach((record) => {
  const values = {};
  headers.forEach((header) => {
    values[header] = jp.query(record, jsonPaths[header]);
  });

  const maxIdCount = Math.max(...Object.values(values).map(v => v.length));
  for (let i = 0; i < maxIdCount; i += 1) {
    const recordOut = headers.map((header) => (
      values[header][i] ? values[header][i].toString() : ''
    ));
    csv.write(`${sanitizeCsvValues(recordOut).join(',')}\n`)
    recordOut;
  }
});

csv.close();
