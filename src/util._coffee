exports.UUID_REG = /[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/

exports.addNull = (cb) ->
	(args...) ->
		cb.apply this, [null].concat args

exports.dummyCB = (e) ->
	if e?
		throw e

exports.findElement = (name, obj) ->
	for name_, elem of obj
		return elem if name_.toLowerCase() is name

arrayEqual = (a, b) ->
	return true if a is b
	return false if a.length isnt b.length
	for element, index in a
		return false if element isnt b[index]
	true

exports.singlify = (func) ->
	calls = []
	(cb, args...) ->
		for call in calls
			if arrayEqual(args, call.args) and call.context is this
				return call.cbs.push cb
		calls.push call =
			args: args
			cbs: [cb]
			context: this
		caller = (args...) ->
			calls = (cl for cl in calls when cl isnt call)
			for cb in call.cbs
				cb.apply this, args
		func.apply this, [caller].concat args

exports.debugOn = false
exports.enableDebugMode = -> exports.debugOn = true

errString = ->
	b = Error.prepareStackTrace
	Error.prepareStackTrace = (a, stack) -> stack
	e = new Error
	Error.captureStackTrace e, this
	s = e.stack
	Error.prepareStackTrace = b
	time = new Date().toString().match(/\d+:\d+:\d+/)[0]
	file = s[2].getFileName().match(/\/(\w*).\w*$/)[1]
	line = do s[2].getLineNumber
	for i in s[2..]
		func = do i.getFunctionName
		if func? and not /throw2cb/.test func
			break
	func = func.replace /module.exports./, ''
	"#{time} #{func} in #{file} at #{line}"

exports.debug = (args...) ->
	return unless exports.debugOn
	console.log.apply null, [errString()].concat args
