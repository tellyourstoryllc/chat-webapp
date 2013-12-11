require('coffee-script');

// TODO: Remove this since it's not safe!
process.env['NODE_TLS_REJECT_UNAUTHORIZED'] = '0';

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
app.use(express.favicon(__dirname + '/public/favicon.ico'));
app.use(express.logger('short'));

// Proxy api requests; must be *before* `bodyParser`.
var apiProxy = function(pattern, host, port) {
  // Default to HTTPS if not specified.
  var useHttps = config.apiUseHttps == null || !! config.apiUseHttps;
  var httpsOptions = true;
  var routingProxy = new httpProxy.HttpProxy({
    https: (useHttps ? httpsOptions : false),
    target: {
      host: host,
      port: port,
      https: (useHttps ? httpsOptions : false)
    }
  });
  return function(req, res, next) {
    var matches = req.url.match(pattern);
    if (matches) {
      // Strip off /api prefix of the URL.
      req.url = matches[1];
      routingProxy.proxyRequest(req, res);
    }
    else {
      next();
    }
  };
};
app.use(apiProxy(/\/api(\/.*)/, config.apiHostname, config.apiPort));

// Redirect http to https.  *Before* `bodyParser`.
if (config.redirectHttpToHttps) {
  app.use(function(req, res, next) {
    var schema = req.headers['x-forwarded-proto'];

    if (schema === 'https') {
      next();
    }
    else {
      res.redirect('https://' + req.headers.host + req.url);
    }
  });
}

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
  res.render('index', { config: config, title: "SkyMob" });
};

app.get('/', renderChatApp);
app.get('/join/*', renderChatApp);
app.get('/login', renderChatApp);
app.get('/signup', renderChatApp);
app.get('/forgot-password', renderChatApp);
app.get('/password/reset/*', renderChatApp);
app.get('/rooms(/*)?', renderChatApp);
app.get('/health_check', function(req, res) {
  res.render('health-check', { config: config });
});


http.createServer(app).listen(app.get('port'), function() {
  console.log("Express server listening on port %d in %s mode",
              app.get('port'), app.get('env'));
});
