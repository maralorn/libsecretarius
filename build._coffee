#!/usr/bin/env _coffee
DEADTIME = 500
deadtime = false
fs = require 'fs-extra'
glob = require 'glob'
path = require 'path'
optimist = require 'optimist'
streamlineCompiler = require 'streamline/lib/compiler/compile'

argv = require('optimist')
	.boolean('debug')
	.alias('d', 'debug')
	.default('debug', false)
	.boolean('watch')
	.alias('w', 'watch')
	.default('watch', false)
	.argv

_node = (_, data, filename, ext) ->
	pre = "/tmp/#{path.basename filename, ext}"
	fs.writeFile "#{pre}#{ext}", data, 'utf8', _
	try
		streamlineCompiler.compile _, ["#{pre}#{ext}"], action: 'compile'
		data = fs.readFile "#{pre}js", 'utf8', _
		fs.unlink "#{pre}js", _
	catch err
		throw err
	finally
		fs.unlink "#{pre}#{ext}", _
	data
	
compiler =
	_coffee:
		ext: 'js'
		compiler: (_, data, filename) -> _node _, data, filename, '_coffee'

parseFile = (_, filepath) ->
	data = fs.readFile filepath, 'utf8', _
	used = []
	dir = path.dirname filepath
	ext = path.extname(filepath)[1..]
	name = path.basename filepath, ext
	while (comp = compiler[ext])?
		ext = comp.ext
		data = comp.compiler _, data, filepath
	dirlist = dir.split path.sep
	dirlist[0] = 'lib'
	dir = path.join.apply null, dirlist
	dirlist.push "#{name}#{ext}"
	fs.mkdirp dir, _
	filepath = path.join.apply null, dirlist
	fs.writeFile filepath, data, 'utf8', _
	console.log new Date().toLocaleString(), 'built', filepath

fs.remove "#{__dirname}/lib", _
filepaths = glob 'src/**/*.*', {}, _
files = {}
for filepath in filepaths
	files[filepath] = parseFile null, filepath

for filepath, future of files
	future _
	watch = (filepath) ->
		fs.watch filepath, (event, filename, _) ->
			if event is 'change'
				parseFile _, filepath
				watch filepath
	if argv.watch
		watch filepath
