require('coffee-script');

// TODO: Remove this since it's not safe!
process.env['NODE_TLS_REJECT_UNAUTHORIZED'] = '0';

var express = require('express');
var http = require('http');
var path = require('path');
var httpProxy = require('http-proxy');
var connectAssets = require('connect-assets');
var request = require('request');

var app = express();
var config = require('./config').getConfig(process.env.NODE_ENV || 'development', app, express);

// Extract API secret so it's not exposed to the browser.
var apiSecret = config.apiSecret;
delete config.apiSecret;

// Expose environment to web app.
config.env = config.env || process.env.NODE_ENV || 'development';

app.set('port', process.env.PORT || 3001);
app.set('views', __dirname + '/views');
app.set('view engine', 'jade');
app.use(express.favicon(__dirname + '/assets/images/' + config.appStaticViewsDirectory + 'favicon.ico'));
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

  // Return given URL with query param added.
  var addQueryParam = function(url, name, value) {
    if (url == null) return url;
    url += (url.indexOf('?') >= 0) ? '&' : '?';
    url += encodeURIComponent(name) + '=' + encodeURIComponent(value);
    return url;
  };

  // Given a request, return the remote client's IP address.
  var remoteIp = function(req) {
    return req.connection.remoteAddress;
  };

  // The actual middleware function.
  return function(req, res, next) {
    var matches = req.url.match(pattern);
    if (matches) {
      // Strip off /api prefix of the URL.
      req.url = matches[1];
      // Add API secret and remote client IP address.
      if (apiSecret != null) {
        req.url = addQueryParam(req.url, 'api_secret', apiSecret);
      }
      req.url = addQueryParam(req.url, 'ip', remoteIp(req));
      routingProxy.proxyRequest(req, res);
    }
    else {
      next();
    }
  };
};
app.use(apiProxy(/\/api(\/.*)/, config.apiHostname, config.apiPort));

// Health check for load balancer needs to be *before* any redirects.
app.use('/health_check', function(req, res, next) {
  res.setHeader('Content-Type', 'text/plain');
  res.setHeader('Cache-Control', 'max-age=0, private, must-revalidate');
  res.send('Healthy');
});

// Health check for faye needs to be *before* any redirects.  Browser code needs
// to be able to check faye with AJAX without doing a cross-domain request.
app.use('/faye_health_check', function(req, res, next) {
  request(config.fayeProtocolAndHost + '/health_check', function(error, fayeResponse, body) {
    res.setHeader('Content-Type', 'text/plain');
    res.setHeader('Cache-Control', 'max-age=0, private, must-revalidate');
    if (! error && fayeResponse.statusCode === 200) {
      res.send('Okay');
    }
    else {
      res.status(503);
      res.send('Down');
    }
  });
});

// Remove www subdomain, and optionally force https.  *Before* `bodyParser`.
app.use(function(req, res, next) {
  var host = req.headers.host;
  var origProtocol = req.headers['x-forwarded-proto'] || req.protocol;
  var protocol = origProtocol;
  if (config.redirectHttpToHttps && origProtocol === 'http') {
    protocol = 'https';
  }
  if (origProtocol !== protocol || /^www/.test(host)) {
    res.redirect(protocol + '://' + host.replace(/^www\./, '') + req.url);
  }
  else {
    next();
  }
});

if (process.env.NODE_ENV === 'production' || process.env.NODE_ENV === 'staging' || process.env.NODE_ENV === 'testing') {
  // Build assets and compress.  connect-assets only does this for production,
  // but we would like staging to be as similar as possible.
  config.assetsBuild = true;
  connectAssets.cssCompilers.styl.compress = true;
  connectAssets.cssCompilers.less.compress = true;
}

app.use(express.bodyParser());
app.use(app.router);
app.use(connectAssets({ build: config.assetsBuild }));
app.use(express.static(path.join(__dirname, 'public')));

app.configure('development', function() {
  app.use(express.errorHandler({
    dumpExceptions: true,
    showStack: true
  }));
});


var renderChatApp = function(req, res) {
  res.render('index', { config: config, title: config.displayTitle });
};

app.get('/', renderChatApp);
app.get('/join/*', renderChatApp);
app.get('/login', renderChatApp);
app.get('/signup', renderChatApp);
app.get('/forgot-password', renderChatApp);
app.get('/password/reset/*', renderChatApp);
app.get('/chat(/*)?', renderChatApp);
app.get('/view(/*)?', renderChatApp);

// SMS invite link /i/:invite_token.
app.get('/i/:invite_token', renderChatApp);
app.get('/mobile', renderChatApp);

app.get('/mobile/help', function(req, res) {
  res.render('mobile-help', { config: config, title: "Help" });
});
app.get('/legal/dmca', function(req, res) {
  res.render(config.appStaticViewsDirectory + 'legal-dmca', { config: config, title: "Copyright Policy" });
});
app.get('/legal/privacy', function(req, res) {
  res.render(config.appStaticViewsDirectory + 'legal-privacy', { config: config, title: "Privacy Policy" });
});
app.get('/legal/tos', function(req, res) {
  res.render(config.appStaticViewsDirectory + 'legal-tos', { config: config, title: "Terms of Service" });
});
app.get('/robots.txt', function(req, res) {
  res.setHeader('Content-Type', 'text/plain');
  res.setHeader('Cache-Control', 'max-age=0, private, must-revalidate');
  res.render('robots', { config: config });
});


http.createServer(app).listen(app.get('port'), function() {
  console.log("Express server listening on port %d in %s mode",
              app.get('port'), app.get('env'));
});
