require('coffee-script');

var express = require('express');
var http = require('http');
var path = require('path');
var httpProxy = require('http-proxy');
var connectAssets = require('connect-assets');

var app = express();
var config = require('./config').getConfig(process.env.NODE_ENV || 'development', app, express);

app.set('port', process.env.PORT || 3001);
app.set('views', __dirname + '/views');
app.set('view engine', 'jade');
app.use(express.favicon());
app.use(express.logger('short'));

// Proxy api requests; must be *before* `bodyParser`.
var routingProxy = new httpProxy.RoutingProxy();
var apiProxy = function(pattern, host, port) {
  return function(req, res, next) {
    var matches = req.url.match(pattern);
    if (matches) {
      // Strip off /api prefix of the URL.
      req.url = matches[1];
      routingProxy.proxyRequest(req, res, { host: host, port: port });
    }
    else {
      next();
    }
  };
};
app.use(apiProxy(/\/api(\/.*)/, config.apiHostname, config.apiPort));

app.use(express.bodyParser());
app.use(app.router);
app.use(connectAssets());
app.use(express.static(path.join(__dirname, 'public')));

app.configure('development', function() {
  app.use(express.errorHandler({
    dumpExceptions: true,
    showStack: true
  }));
});


var renderChatApp = function(req, res) {
  res.render('index', { config: config, title: "Chat App" });
};

app.get('/', renderChatApp);
app.get('/join/*', renderChatApp);
app.get('/login', renderChatApp);
app.get('/signup', renderChatApp);
app.get('/forgot-password', renderChatApp);
app.get('/rooms(/*)?', renderChatApp);


http.createServer(app).listen(app.get('port'), function() {
  console.log("Express server listening on port %d in %s mode",
              app.get('port'), app.get('env'));
});
