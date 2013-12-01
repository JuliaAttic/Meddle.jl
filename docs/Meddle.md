# Meddle

Meddle is a middleware stack for use with HttpServer.jl.

## Installation:

    :::julia
    julia> Pkg.add("Meddle")

## Basic Example:

Define a 'stack' of middleware through which incoming `Request`s are processed:

    :::julia
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
