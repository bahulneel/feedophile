"use strict"

cluster = require 'cluster'
http = require 'http'
numCPUs = (require 'os').cpus().length
zmq = require 'zmq'
uuid = require 'uuid'
edn = require 'jsedn'

pubSubAddr = 'ipc:///tmp/feedophile.down.sock'
pubSubRepAddr = 'ipc:///tmp/feedophile.up.sock'

getReq = (req) ->
	msg = 
		method: req.method
		url: req.url
		headers: req.headers

class Message
	constructor: (msg) ->
		@id = msg.id
		@msg = msg.msg
	ednEncode: ->
		edn.encode new edn.Tagged new edn.Tag("feedophile", "message"),
			id: @id
			msg: @msg

edn.setTagAction new edn.Tag('feedophile', 'message'), (obj) ->
    return new Message edn.toJS obj;

master = ->
	do cluster.fork for i in [0..numCPUs]

	sockDown = zmq.socket 'push'
	sockDown.bindSync pubSubAddr

	sockUp = zmq.socket 'pull'
	sockUp.bindSync pubSubRepAddr

	resmap = {}

	http.createServer (req, res) ->
		msg = new Message 
			id: do uuid.v1
			msg: getReq req
		resmap[msg.id] = res
		sockDown.send edn.encode msg
	.listen 3000, "127.0.0.1"

	sockUp.on 'message', (strMsg) ->
		msg = edn.parse strMsg.toString()
		res = resmap[msg.id]
		delete resmap[msg.id]
		res.writeHead msg.msg.code, msg.msg.headers
		res.end msg.msg.msg
	console.log('Server running at http://127.0.0.1:3000/');

worker = ->
	sockDown = zmq.socket 'pull'
	sockDown.connect pubSubAddr

	sockUp = zmq.socket 'push'
	sockUp.connect pubSubRepAddr

	sockDown.on 'message', (strMsg) ->
		msg = edn.parse strMsg.toString()
		reply = new Message
			id: msg.id
			msg:
				code: 200
				headers: {'Content-Type': 'text/plain'}
				msg: 'Hello World from ' + process.pid + '\n'
		sockUp.send edn.encode reply


if cluster.isMaster
	do master
else
	do worker
