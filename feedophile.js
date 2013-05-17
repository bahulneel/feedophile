var http = require('http'),
    m2node = require('m2node');

var server = http.createServer(function (req, res) {
  res.writeHead(200, {'Content-Type': 'text/plain'});
  res.end('Hello World\n');
});

m2node.run(server, {
  send_spec: 'tcp://127.0.0.1:9996',
  recv_spec: 'tcp://127.0.0.1:9997'
});
