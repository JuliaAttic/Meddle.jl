Meddle
======

Meddle is a middleware stack for use with [HttpServer.jl](https://github.com/hackerschool/HttpServer.jl).

##Installation:

In the Julia REPL, run: `Pkg.add("Meddle")`.
You will also need to install Joyent's HTTP parsing library;
see the instructions in [HttpParser.jl's README](https://github.com/hackerschool/HttpParser.jl).

##Example:

Define a 'stack' of middleware through which incoming `Requests` are processed:

~~~~.jl
using HttpServer
using Meddle

stack = middleware(DefaultHeaders, CookieDecoder, FileServer(pwd()), NotFound)
http = HttpHandler((req, res)->Meddle.handle(stack, req, res))

for event in split("connect read write close error")
    http.events[event] = (event->(client, args...)->println(client.id,": $event"))(event)
end
http.events["error"] = (client, err)->println(err)
http.events["listen"] = (port)->println("Listening on $port...")

server = Server(http)
run(server, 8000)
~~~~
