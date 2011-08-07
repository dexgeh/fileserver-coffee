A simple file server written in coffee-script.

Sample usage:

    http = require 'http'
    fileserver = require './fileserver'
    server = http.createServer fileserver.getFileServer '.'
    server.listen 8080

Enable directory listing:

    fileserver.getFileServer '.', true

Custom error handling:

    server = http.createServer fileserver.getFileServer '.', false, (req, res, code, err) ->
        res.writeHead code,
            'Content-Type' : 'text/html'
        res.end "Error #{code}!!!"

Customize the Server response header:

    filserver.serverHeader = "'; DROP TABLE SERVER --"
