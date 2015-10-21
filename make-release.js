var fs = require('fs');

var fileList = ['control.lua', 'info.json']

var data = fs.readFileSync('info.json', 'utf-8');
var parsedData = JSON.parse(data);
var outDir = 'releases/' + parsedData.name + '_' + parsedData.version;

console.log('Create ' + outDir);
fs.mkdirSync(outDir);
fileList.forEach(function(fn) {
	console.log('Copy ' + fn);
	fs.createReadStream(fn).pipe(fs.createWriteStream(outDir + '/' + fn));
});
console.log('Done!');
