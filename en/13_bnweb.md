# Appendix G: BNWeb

[← Previous: Appendix F: BNLog](12_bnlog.md) · [Contents](toc.md)

`BNWeb` is the optional domain library for HTTP communication in Basic Next. It provides HTTP server and client adapters, route registration, middleware filters, cookie handling, session management, static file serving, and security access control.

`BNWeb` is supported under both toolchain backends: the reference interpreter (`bni`) and the native LLVM compiler (`bnc`).

## Architecture and Capability Model

In accordance with Basic Next architectural principles, `BNWeb` is completely decoupled from the language core runtime (`bn_rt`) and the compiler executable (`bnc`). When compiled with `bnc`, the static web library is linked conditionally into the final binary only if symbols from `BNWeb` appear in the emitted intermediate representation.

`BNWeb` requires explicit imports and does not grant ambient system privileges:
* Network socket operations require `IMPORT HOST.Net AS Net`.
* Static file serving requires `IMPORT HOST.FileSystem AS FS`.
* Logging integrations require `IMPORT BNLog AS Log`.

To import the web module:

```basic
IMPORT BNWeb AS Web
IMPORT HOST.Net AS Net
```

## HTTP Server and Route Registration

An HTTP server is instantiated using `NEW Web.Server()`. Handlers and filters are standard Basic Next functions accepting a `Web.Request` and a `Web.Response`.

Routes are registered with HTTP method and path pattern. The server binds to a `Net.Endpoint` and begins accepting connections:

```basic
IMPORT BNWeb AS Web
IMPORT HOST.Net AS Net

FUNCTION HelloHandler(request AS Web.Request, response AS Web.Response) AS VOID
    IF response.SetStatus(200) IS Error THEN
        RETURN
    END IF
    IF response.SetHeader("Content-Type", "text/plain") IS Error THEN
        RETURN
    END IF
    IF response.Write("Hello from Basic Next!") IS Error THEN
        RETURN
    END IF
END FUNCTION

FUNCTION Filter(request AS Web.Request, response AS Web.Response) AS VOID
    IF response.SetHeader("X-Framework", "BasicNext") IS Error THEN
        RETURN
    END IF
END FUNCTION

FUNCTION Start() AS VOID
    LET address AS Net.Address OR Error = Net.Address.Parse("127.0.0.1")
    IF address IS Error THEN
        PRINT "address parse failed"
        RETURN
    END IF
    LET endpoint AS Net.Endpoint OR Error = Net.Endpoint.Create(address, 8080)
    IF endpoint IS Error THEN
        PRINT "endpoint creation failed"
        RETURN
    END IF

    LET server AS Web.Server = NEW Web.Server()
    IF server.AddFilter(Filter) IS Error THEN
        PRINT "filter registration failed"
        RETURN
    END IF
    IF server.Route("GET", "/", HelloHandler) IS Error THEN
        PRINT "route registration failed"
        RETURN
    END IF

    LET started AS VOID OR Error = server.Start(endpoint)
    IF started IS Error THEN
        PRINT "server start failed"
        RETURN
    END IF
    PRINT "Server listening on port 8080"
END FUNCTION
```

## Cookies and Cookie Jars

`BNWeb` supports cookies directly on responses and through client-side cookie jars.

### Response Cookies

Cookies can be configured with standard attributes including max age, domain, path, `Secure`, `HttpOnly`, and `SameSite` policies:

```basic
IMPORT BNWeb AS Web

FUNCTION ConfigureResponse() AS VOID
    LET resp AS Web.Response = NEW Web.Response()
    IF resp.SetStatus(200) IS Error THEN
        RETURN
    END IF
    IF resp.SetCookieWithPolicy("auth", "session_token", "example.com", "/", 3600000, TRUE, TRUE, "Strict") IS Error THEN
        PRINT "cookie configuration failed"
        RETURN
    END IF
END FUNCTION
```

### Client CookieJar

The `Web.CookieJar` class maintains a store of cookies partitioned by domain and path:

```basic
IMPORT BNWeb AS Web

FUNCTION Start() AS VOID
    LET jar AS Web.CookieJar = NEW Web.CookieJar()
    IF jar.Set("token", "abc123xyz", "example.test", "/", 60000) IS Error THEN
        PRINT "cookie set error"
        RETURN
    END IF

    LET token AS STRING OR Error = jar.Get("token", "example.test", "/")
    IF token IS Error THEN
        PRINT "cookie lookup error"
        RETURN
    END IF
    PRINT "Retrieved cookie:", token
    PRINT "Total cookies:", jar.Count()
END FUNCTION
```

## Session Management

`BNWeb` provides server-side session management via `Web.SessionStore`:
* Created with a maximum capacity and an idle timeout in milliseconds.
* Generates opaque session identifiers via `store.Create(data)`.
* Retrieves stored session data via `store.Get(sessionId)`.

```basic
IMPORT BNWeb AS Web

FUNCTION Start() AS VOID
    LET store AS Web.SessionStore OR Error = Web.SessionStore.New(1000, 1800000)
    IF store IS Error THEN
        PRINT "failed to create session store"
        RETURN
    END IF

    LET sid AS STRING OR Error = store.Create("user_id=42;role=admin")
    IF sid IS Error THEN
        PRINT "failed to create session"
        RETURN
    END IF

    LET sessionData AS STRING OR Error = store.Get(sid)
    IF sessionData IS Error THEN
        PRINT "session lookup failed"
        RETURN
    END IF
    PRINT "Session data:", sessionData
END FUNCTION
```

## Static File Serving

Static files can be served from a local directory under a defined URL prefix. To maintain security boundaries:
* The calling program must explicitly import `HOST.FileSystem`. Without this capability, `server.Static` returns an error.
* Directory traversal attacks (`..` and embedded null bytes) are rejected automatically.
* Hidden files and dot-segments are excluded from serving.
* Index files (`index.html`) are resolved within directories.

```basic
IMPORT BNWeb AS Web
IMPORT HOST.FileSystem AS FS

FUNCTION ConfigureStatic(server AS Web.Server) AS VOID
    LET result AS VOID OR Error = server.Static("/static", "/var/www/public")
    IF result IS Error THEN
        PRINT "static file configuration failed:", result.Message
        RETURN
    END IF
END FUNCTION
```

## HTML Scraping and Network Access Control (ACL)

`BNWeb` includes helper utilities for inspecting HTML responses and restricting endpoints by subnet:

```basic
IMPORT BNWeb AS Web
IMPORT HOST.Net AS Net

FUNCTION Start() AS VOID
    LET scraper AS Web.Scraper = NEW Web.Scraper("<title>Overview</title><div>Content</div>")
    PRINT "Title:", scraper.Text("title")
    PRINT "Div:", scraper.Text("div")

    LET acl AS Web.ACL = NEW Web.ACL()
    LET privateRange AS Net.CIDR OR Error = Net.CIDR.Parse("192.168.0.0/16")
    IF privateRange IS Error THEN
        PRINT "invalid CIDR"
        RETURN
    END IF
    IF acl.Deny(privateRange) IS Error THEN
        PRINT "failed to register subnet rule"
        RETURN
    END IF

    LET clientIp AS Net.Address OR Error = Net.Address.Parse("192.168.1.100")
    IF clientIp IS Error THEN
        PRINT "invalid address"
        RETURN
    END IF
    LET isDenied AS BOOLEAN OR Error = acl.Check(clientIp)
    IF isDenied IS Error THEN
        PRINT "ACL check failed"
        RETURN
    END IF
    PRINT "Access denied:", isDenied
END FUNCTION
```

---

[Next: Appendix H: BNData →](14_bndata.md)
