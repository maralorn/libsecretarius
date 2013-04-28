Source = null
url = '/sseupdate'
listen = (cb) ->
	emit = (name) -> (event) ->
		msg =
			data: JSON.parse event.data
			name: name
		cb msg
	sse = new Source(url)
	sse.addEventListener 'changed', emit('changed'), false
	sse.addEventListener 'inbox', emit('inbox'), false
	sse.addEventListener 'deleted', emit('deleted'), false
	sse.addEventListener 'new', emit('new'), false

if module?
	Source = require 'eventsource'
	module.exports = (host, cb) ->
		url = "#{host}#{url}"
		listen cb
else
	Source = EventSource
	ports = []

	self.addEventListener 'connect',((e) ->
		ports.push port = e.ports[0]
		do port.start)

	listen (msg) ->
		for port in ports
			port.postMessage msg
