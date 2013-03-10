module.exports = (host = 'http://localhost:3000') ->
	model = {}

	inNode = not (inBrowser = window?)

	if inNode
		model.connect = (_host) ->
			host = _host

	class ModelObject
		on: (event, cb) ->
			@_cbs = {} unless @_cbs?
			@_cbs[event] = [] unless @_cbs[event]?
			@_cbs[event].push cb unless cb in @_cbs[event]
		
		emit: (event, data) =>
			if @_cbs?[event]?
				for cb in @_cbs[event]
#				try
						cb.call this, data
#				catch err
#					@removeCb event, cb
			
		removeCb: (event, cb) ->
			@_cbs[event] = (elem for elem in @_cbs[event] when elem isnt cb)
			delete @_cbs[event] if @_cbs[event] == []
			debug event, "callback removed", @constructor.name

		onChanged: (cb) ->
			@on("changed", cb)
				
		onDeleted: (cb) ->
			@on("deleted", cb)

		change: (data) ->
			@emit "changed", data

		delete: ->
			@emit "deleted"

		cbs = {}
		@on: (event, cb) ->
			cbs[@name] = {} unless cbs[@name]?
			obj = cbs[@name]
			obj[event] = [] unless obj[event]?
			obj[event].push cb unless cb in obj[event]
		
		@emit: (event, data) ->
			if cbs[@name]?[event]?
				for cb in cbs[@name][event]
#				try
						cb data
#				catch err
#					@removeCb event, cb
			
		@removeCb: (event, cb) ->
			cbs[@name][event] = (elem for elem in cbs[@name][event] when elem isnt cb)
			delete cbs[@name][event] if cbs[@name][event] == []
			debug event, "callback removed", @name

		@onChanged: (cb) ->
			@on("changed", cb)
				
		@onDeleted: (cb) ->
			@on("deleted", cb)

		@change: (data) ->
			@emit "changed", data

	class InfoCache
		constructor: ->
			@infos = {}

		registerInfo: (info) ->
			@infos[info.id] = info

		delete: (id) ->
			if @infos[id]?
				do @infos[id].delete
				@unregisterInfo @infos[id]

		unregisterInfo: (info) ->
			if info.id? and @infos[info.id]?
				delete @infos[info.id]

		updateInfo: (values) ->
			@storeInfo values, true

		storeInfo: (values, mustExist = false) ->
			unless (info = @infos[values.id])? or mustExist
				info = new (model.getClassByType values.type) values.id
				@registerInfo info
			info?._store values

		getInformation: util.singlify (_, id) ->
			if id? and util.UUID_REG.test id
				unless @infos[id]?
					@storeInfo new model.Information(id)._get(_)
				@infos[id]
			else
				null

	model.cache = new InfoCache

	updatecb = (data, name) ->
		switch name
			when 'changed'
				model.cache.updateInfo data
			when 'inbox'
				model.inbox._store (-> return), data
			when 'deleted'
				model.cache.delete data.id
				util.findElement(data.type, model).deleted data.id
			when 'new'
				util.findElement(data.type, model).new data.id

	if inBrowser
		port = new SharedWorker('events.js').port
		port.addEventListener 'message', (event) -> updatecb event.data.data, event.data.name
		do port.start
	else
		require('./events') updatecb
		
	getInfos = (_, cls, filter, params = {}) ->
		params.filter = filter
		list = new cls()._get _, params
		for values in list
			model.cache.storeInfo values
		list
		
	if inBrowser
		request = (cb, type, data, url) ->
			options =
				type: type
				success: util.addNull cb
				dataType: "json"
			if data? then request.data = data
			$.ajax options
	else
		httprequest = require('request')
		request = (_, type, data, url) ->
			options =
				method: type.toUpperCase()
				url: "#{host}/#{url}"
				json: true
				form: data
			httprequest(options, _).body
		
	class PGObject extends ModelObject
		constructor: (@id) ->
				
		_get: (_, data, url)->
			@_call _, "get", data, url

		_put: (_, data, url) ->
			@_call _, "put", data, url
		
		_delete: (_, url) ->
			@_call _, "delete", url

		_patch: (_, data, url) ->
			@_call _, "patch", data, url

		_post: (_, data, url) ->
			@_call _, "post", data, url

		_call: (_, type, data, url) ->
			url = @_url() unless url?
			console.log "#{type.toUpperCase()} #{url} (#{if data? then JSON.stringify data else ""})"
			request _, type, data, url

	class model.Information extends PGObject
		constructor: (@id) ->
			@values = false
			tempType = @constructor.name.toLowerCase()
			@type = tempType if tempType != "information"

		_create: (_, args) ->
			{id: @id} = @_post _, args
			model.cache.registerInfo this
			@id

		addReference: (_, reference) ->
			@_patch _,
				method: "addReference"
				reference: reference.id

		removeReference: (_, reference) ->
			@_patch _,
				method: "removeReference"
				reference: reference.id
			
		getType: (_) ->
			unless @type?
				{type: @type} = @_get _,
					filter: "type"
			@type

		get: (_) ->
			unless @values
				@_store @_get _, values
			this

		setStatus: (_, status) ->
			@_patch _,
				method: "setStatus"
				status: status

		setDelay: (_, delay) ->
			@_patch _,
				method: "setDelay"
				delay: delay

		attach: (_, file) ->
			@_patch _,
				method: "attach"
				file: file.id

		detach: (_, file) ->
			@_patch _,
				method: "detach"
				file: file.id

		getReferences: (_) ->
			@_get _,
				filter: "references"

		_url: -> "#{if @type? then @type else "information"}#{if @id? then "/#{@id}" else ""}"

		_store: (values) ->
			@values = true
			(@[key] = value) for key,value of values
			@change values

		@getAll: util.singlify (_) ->
			all = getInfos _, this, 'all'
			ids[@name] = (info.id for info in all)

		ids = []
		@getAllIDs: util.singlify (_) ->
			unless ids[@name]?
				@getAll _
			ids[@name]
		
		@new: (id) ->
			if ids[@name]
				ids[@name].push id
				@change ids[@name]
			
		@deleted: (id) ->
			if ids[@name]
				ids[@name] = (i for i in ids[@name] when i isnt id)
				@change ids[@name]
	"""
	class File extends PGObject
		create: (name) ->
		getName: ->
		delete: ->
	"""
	class model.Note extends model.Information
		create: (_, content) ->
			@_create _,
				content: content,

		setContent: (_, content) ->
			@_patch _,
				method: "setContent"
				content: content

	class model.Task extends model.Information
		done: (_) ->
			@_patch _,
				method: 'done'

		undo: (_) ->
			@_patch _,
				method: 'undo'

		setParent: (_, parent) ->
			@_patch _,
				parent: parent?.id
				method: 'setParent'

		setDeadline: (_, deadline) ->
			@_patch _,
				method: "setDeadline"
				deadline: deadline

		setDescription: (_, description) ->
			@_patch _,
				method: "setDescription"
				description: description
			

	class model.Project extends model.Task
		create: (_, description, referencing=null, parent=null) ->
			@_create _,
				description: description
				referencing: referencing?.id
				parent: parent?.id

		collapse: (_) ->
			@_patch _,
				method: 'collapse'

		uncollapse: (_) ->
			@_patch _,
				method: 'uncollapse'

	class model.Asap extends model.Task
		create: (_, description, list, referencing=null, project=null) ->
			@_create _,
				description: description
				list: list.id
				referencing: referencing?.id
				project: project?.id

		setList: (_, list) ->
			@_patch _,
				list: list.id
				method: 'setList'

	class model.AsapList extends model.Information
		create: (_, name) ->
			@_create _,
				name: name

		rename: (_, name) ->
			@_patch _,
				method: "rename"
				name: name
	"""
	class model.SocialEntity extends model.Information
		create: ->
			
	class Circle extends SocialEntity
		create: (name) ->
		@getByName: (name) =>
		rename: (name) ->

	class Contact extends SocialEntity
		create: (nameMap) ->
		setValues: (nameMap) ->
		addAccount: (account, description=null, priority=0) ->
		removeAccount: (account) ->
		addAddress: (place, description=null) ->
		removeAddress: (place) ->
		enterCircle: (circle) ->
		leaveCircle: (circle) ->

	class Place extends Information

		create: (valueMap) ->

		setValues: (valueMap) ->
		setParent: (place) ->
		removeParent: ->

	class Appointment extends Information

		create: (description, date, time=null, length=null, referencing=null) ->

		setValues: (valueMap) ->
		
		setPlace: (place) ->

		addException: (appointment, exceptionMove='no') ->
		removeException: (appointment) ->

		addFilter: (type, value) ->
		removeFilter: (type, value) ->

		addParticipant: (participant) ->
		removeParticipant: (participant) ->

	class Protocol extends PGObject
		@find: (name) ->
		delete: ->

	class Server extends PGObject
		@find: (name, protocol) ->
		delete: ->

	class Communicator extends Information
		create: (username, server) ->
		changeServer: (server) ->
		setValues: (valueMap) ->

	class Account extends Communicator
		create: (username, server) ->
		@find: (username, server) ->
		join: (room, role=null) ->
		leave: (room, role=null) ->

	class UserAccount extends Account
		setValues: ->
		create: (account) ->
		downGrade: ->
		@getAll: ->

	class Room extends Communicator
		create: (name) ->
		setMOTD: (motd) ->

	class Communication extends Information
		create: (from, time=new Date()) ->
		setSender: (from) ->
		setTime: (time=new Date()) ->
		send: ->
		sent: ->
		draft: ->
		addRecipient: (recipient, mode, resource=null) ->
		removeRecipient: (recipient, mode) ->
		getToSend: (from) ->

	class Message extends Communication
		create: (from, subject=null, body=null, time=new Date()) ->
		setValues: (valueMap) ->

	class Presence extends Communication
		create: (from, time=new Date()) ->
		addResource: (resource) ->

	class Resource extends PGObject
		create: (name, status, message) ->
		delete: ->

	class Daemon extends PGObject
		registrate: (name, status) ->
		setStatus: (status) ->
		setMessage: (message) ->
		deregistrate: ->
		@getAll: ->

	class Maybe extends PGObject
		getSize: ->
		getList: ->
	"""
	class Inbox extends PGObject
		getSize: (_) ->
			@get(_).size

		getFirst: (_) ->
			@get(_).first

		get: util.singlify (_) ->
			unless @values?
				@_store _, @_get _, null, "inbox"
			@values

		_store: (_, @values) ->
			@values.first = model.cache.getInformation _, @values.first if @values.first?
			@change @values
	"""
	class Urgent extends PGObject
		 getSize: ->
		 getList: ->
	"""
	model.inbox = new Inbox
	model

module.exports.util = util = require './util'
