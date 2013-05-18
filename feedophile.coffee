"use strict"

cluster = require 'cluster'
http = require 'http'
numCPUs = (require 'os').cpus().length + 1
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

master = ->
	do cluster.fork for i in [0..numCPUs]

	sockDown = zmq.socket 'push'
	sockDown.bindSync pubSubAddr

	sockUp = zmq.socket 'pull'
	sockUp.bindSync pubSubRepAddr

	resmap = {}

	http.createServer (req, res) ->
		msg =
			id: do uuid.v1
			req: getReq req
		resmap[msg.id] = res
		sockDown.send JSON.stringify msg
	.listen 3000, "127.0.0.1"

	sockUp.on 'message', (jsonMsg) ->
		msg = JSON.parse jsonMsg
		res = resmap[msg.id]
		delete resmap[msg.id]
		res.writeHead msg.code, msg.headers
		res.end msg.msg
	console.log('Server running at http://127.0.0.1:3000/');

worker = ->
	sockDown = zmq.socket 'pull'
	sockDown.connect pubSubAddr

	sockUp = zmq.socket 'push'
	sockUp.connect pubSubRepAddr

	sockDown.on 'message', (jsonMsg) ->
		msg = JSON.parse jsonMsg
		reply =
			id: msg.id
			code: 200
			headers: {'Content-Type': 'text/plain'}
			msg: 'Hello World from ' + process.pid + '\n'
		sockUp.send JSON.stringify reply


if cluster.isMaster
	do master
else
	do worker
