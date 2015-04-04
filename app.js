var express = require('express');
var path = require('path');
var favicon = require('serve-favicon');
var logger = require('morgan');
var cookieParser = require('cookie-parser');
var bodyParser = require('body-parser');

var routes = require('./routes/index');
var users = require('./routes/users');

var pg = require('pg');

var clientEventHandler = require('./lib/client_event_handler')
var redisListener = require('./lib/redis_listener')(clientEventHandler);
var slackListener = require('./lib/slack/listener')(pg, clientEventHandler);
