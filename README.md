Meddle
======

[![Meddle](http://pkg.julialang.org/badges/Meddle_0.3.svg)](http://pkg.julialang.org/?pkg=Meddle&ver=0.3)
[![Meddle](http://pkg.julialang.org/badges/Meddle_0.4.svg)](http://pkg.julialang.org/?pkg=Meddle&ver=0.4)

Meddle is a middleware stack for use with [HttpServer.jl](https://github.com/hackerschool/HttpServer.jl).

**Installation**: `Pkg.add("Meddle")`

##Example:

Define a 'stack' of middleware through which incoming `Requests` are processed:

~~~~.jl
using HttpServer
using Meddle

stack = middleware(DefaultHeaders, URLDecoder, CookieDecoder, FileServer(pwd()), NotFound)
http = HttpHandler((req, res)->Meddle.handle(stack, MeddleRequest(req, Dict{Symbol,Any}()), res))

for event in split("connect read write close error")
    http.events[event] = (event->(client, args...)->println(client.id,": $event"))(event)
end
http.events["error"] = (client, err)->println(err)
http.events["listen"] = (port)->println("Listening on $port...")

server = Server(http)
run(server, 8000)
~~~~


~~~~
:::::::::::::
::         ::
:: Made at ::
::         ::
:::::::::::::
     ::
Hacker School
:::::::::::::
~~~~
