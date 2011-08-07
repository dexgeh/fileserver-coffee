A simple file server written in coffee-script.

Sample usage:
    http = require 'http'
    fileserver = require './fileserver'
    server = http.createServer fileserver.getFileServer('.')
    server.listen 8080


