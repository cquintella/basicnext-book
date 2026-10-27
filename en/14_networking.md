# Networking

[← Previous: Files](13_files.md) · [Contents](toc.md)

A program that talks to other machines needs three things from its host: a way to name the machines, a way to exchange data with them, and a way to tell when one is not answering. In Basic Next all three come from the host capability `HOST.Net`, imported like the others ([chapter 12](12_host.md)). It covers IPv4 and IPv6 addresses, name resolution through the system resolver, the two transport protocols of the Internet — TCP for reliable streams of bytes and UDP for independent datagrams — and ICMP Echo, the message behind the familiar `ping`. The protocols themselves are implemented by the operating system; `HOST.Net` gives the program typed, bounded access to them.

This chapter presents each part with a complete program that runs on the loopback interface of the machine itself, so that no example needs access to the Internet. For HTTP, the protocol of the Web, the program uses the `BNWeb` module, introduced at the end of the chapter.

```basic
IMPORT HOST.Net AS Net
```

## Addresses, Ports, and Protocols

Machines on a network exchange data according to *protocols*: agreed rules for the format of messages and the order in which they are sent. The protocols of the Internet are organized in layers, each relying on the one below. The *Internet Protocol* (IP) carries individual packets from one machine to another; it identifies each network interface by an *IP address*, either a 32-bit IPv4 address written as four decimal numbers (`192.168.10.7`) or a 128-bit IPv6 address written in hexadecimal groups (`::1`) (Postel, 1981a; Deering and Hinden, 2017). A packet delivered to a machine must then reach the right program, and the transport protocols add a *port*, a 16-bit number that identifies one communication endpoint on that machine. An address and a port together, such as `127.0.0.1:8080`, form an *endpoint*.

Two transport protocols sit on top of IP. *TCP* provides a reliable, ordered stream of bytes over a connection between two endpoints, retransmitting what is lost (Eddy, 2022). *UDP* sends independent datagrams with no connection and no guarantee of delivery (Postel, 1980). Alongside them, *ICMP* carries control messages, among them the Echo request and reply used to test whether a machine answers (Postel, 1981b). People, finally, prefer names to numbers: the *Domain Name System* (DNS) translates a host name such as `example.com` into its addresses, a step called *name resolution* (Mockapetris, 1987). A *network* or *subnet* is a range of addresses that share a common prefix, written in CIDR notation as the first address followed by the length of the prefix in bits: `192.168.10.0/24` covers the 256 addresses that begin with `192.168.10`. The address `127.0.0.1` (and `::1` in IPv6) is the *loopback* address, which always designates the local machine.

## Design Principles

Two rules shape the whole capability, and both exist to make network failures explicit rather than surprising.

**Networking is typed.** An `Address` is not a string: text is parsed and validated once, and the result is a value that can only hold a well-formed address. An `Endpoint` pairs an address with a port. A malformed address is therefore an `Error` at the point where it enters the program, not a failure several calls later in a connection attempt.

**Every wait is bounded.** Each operation that may wait for the network — resolving a name, accepting or opening a connection, reading, receiving, pinging — takes a timeout in milliseconds. A program cannot hang forever on an unresponsive peer; it receives an `Error` and decides what to do.

## Addresses, Networks, and Name Resolution

`Net.Address.Parse` accepts IPv4 and IPv6 text and rejects host names; `Net.Resolve` is the only operation that turns a name into addresses.

```basic
IMPORT HOST.Net AS Net

FUNCTION Describe(text AS STRING) AS VOID
    LET address AS Net.Address OR Error = Net.Address.Parse(text)
    IF address IS Error THEN
        PRINT text, "is not an address:", address.Message
    ELSE
        PRINT address.ToString(), "loopback:", address.IsLoopback(), "private:", address.IsPrivate()
    END IF
END FUNCTION

FUNCTION Start() AS INTEGER
    Describe("127.0.0.1")
    Describe("192.168.10.7")
    Describe("::1")
    Describe("example.com")

    LET lan AS Net.CIDR OR Error = Net.CIDR.Parse("192.168.10.0/24")
    LET host AS Net.Address OR Error = Net.Address.Parse("192.168.10.7")
    IF lan IS Error OR host IS Error THEN
        PRINT "parse failed"
        RETURN 1
    END IF
    PRINT "prefix:", lan.PrefixLength(), "contains 192.168.10.7:", lan.Contains(host)

    LET found AS Net.Addresses OR Error = Net.Resolve("localhost", 2000)
    IF found IS Error THEN
        PRINT "resolve failed:", found.Message
        RETURN 1
    END IF
    FOR i AS INTEGER = 0 TO found.Count() - 1
        LET item AS Net.Address OR Error = found.Get(i)
        IF item IS Error THEN
            PRINT "entry", i, "failed:", item.Message
        ELSE
            PRINT "localhost ->", item.ToString()
        END IF
    END FOR
    RETURN 0
END FUNCTION
```

```
127.0.0.1 loopback: TRUE private: FALSE
192.168.10.7 loopback: FALSE private: TRUE
::1 loopback: TRUE private: FALSE
example.com is not an address: cannot parse "example.com" as an IP address
prefix: 24 contains 192.168.10.7: TRUE
localhost -> ::1
localhost -> 127.0.0.1
```

`Resolve` returns an `Addresses` collection in the system's order, read with `Count()` and `Get(i)`.

`CIDR.Parse` is as strict as `Address.Parse`. The prefix is plain decimal (`/8`, not `/08` or `/+8`), and the address must be the network address: `10.0.0.1/8` is an `Error` whose cause says to write `10.0.0.0/8`. A typo in an ACL or an egress list therefore fails at once instead of silently naming a different network.

## TCP: Reliable Streams

A TCP *connection* is opened by one side and accepted by the other. The side that accepts is conventionally the *server*: it *listens* on an endpoint and waits for *clients* to connect. `Net.TCPListen` opens listeners on a set of endpoints, `Accept` waits for a connection, and `Net.TCPConnect` connects. `Read` and `Write` move bytes through a `POINTER TO BYTE[]` buffer; `Read` returns `EOF` when the peer has closed. This program is both server and client on the loopback interface:

```basic
IMPORT HOST.Net AS Net

FUNCTION Start() AS INTEGER
    LET loopback AS Net.Address OR Error = Net.Address.Parse("127.0.0.1")
    IF loopback IS Error THEN
        RETURN 1
    END IF
    // Port 0 asks the system for any free port.
    LET wanted AS Net.Endpoint OR Error = Net.Endpoint.Create(loopback, 0)
    IF wanted IS Error THEN
        RETURN 1
    END IF
    LET endpoints AS Net.Endpoint[1] = [wanted]
    LET listener AS Net.TCPListener OR Error = Net.TCPListen(endpoints, 8)
    IF listener IS Error THEN
        PRINT "listen failed:", listener.Message
        RETURN 1
    END IF
    LET bound AS Net.Endpoint OR Error = listener.LocalEndpoint()
    IF bound IS Error THEN
        RETURN 1
    END IF
    PRINT "listening on port", bound.Port()

    LET client AS Net.TCPStream OR Error = Net.TCPConnect(bound, 2000)
    LET server AS Net.TCPStream OR Error = listener.Accept(2000)
    IF client IS Error OR server IS Error THEN
        PRINT "connection failed"
        RETURN 1
    END IF

    LET message AS POINTER TO BYTE[] = NEW BYTE[2]
    message[0] = 72    // 'H'
    message[1] = 105   // 'i'
    LET sent AS INTEGER OR Error = client.Write(message, 2)
    IF sent IS Error THEN
        PRINT "write failed:", sent.Message
        RETURN 1
    END IF

    LET received AS POINTER TO BYTE[] = NEW BYTE[2]
    LET count AS INTEGER OR EOF OR Error = server.Read(received, 2)
    IF count IS INTEGER THEN
        PRINT "server read", count, "bytes:", received[0], received[1]
    END IF

    client.Close()
    server.Close()
    listener.Close()
    RELEASE message
    RELEASE received
    RETURN 0
END FUNCTION
```

```
listening on port 64483
server read 2 bytes: 72 105
```

Port `0` asks the system for a free port; `LocalEndpoint()` reports which one was chosen.

## UDP: Independent Datagrams

Because a datagram stands alone, UDP needs no connection to be opened or closed, and it suits short request-and-reply exchanges, such as name lookups or measurements, where a lost message is simply asked for again. `Net.UDPBind` opens a socket, `SendTo` sends one datagram, and `Receive(size, timeout)` returns a `UDPPacket` that knows its source, its size, and whether it was truncated to fit:

```basic
IMPORT HOST.Net AS Net

FUNCTION Start() AS INTEGER
    LET loopback AS Net.Address OR Error = Net.Address.Parse("127.0.0.1")
    IF loopback IS Error THEN
        RETURN 1
    END IF
    LET any AS Net.Endpoint OR Error = Net.Endpoint.Create(loopback, 0)
    IF any IS Error THEN
        RETURN 1
    END IF
    LET receiver AS Net.UDPSocket OR Error = Net.UDPBind(any)
    LET sender AS Net.UDPSocket OR Error = Net.UDPBind(any)
    IF receiver IS Error OR sender IS Error THEN
        PRINT "bind failed"
        RETURN 1
    END IF
    LET target AS Net.Endpoint OR Error = receiver.LocalEndpoint()
    IF target IS Error THEN
        RETURN 1
    END IF

    LET datagram AS POINTER TO BYTE[] = NEW BYTE[3]
    datagram[0] = 1
    datagram[1] = 2
    datagram[2] = 3
    LET sent AS INTEGER OR Error = sender.SendTo(target, datagram, 3)
    IF sent IS Error THEN
        PRINT "send failed:", sent.Message
        RETURN 1
    END IF

    // Receive at most 16 bytes, waiting up to 2000 ms.
    LET packet AS Net.UDPPacket OR Error = receiver.Receive(16, 2000)
    IF packet IS Error THEN
        PRINT "receive failed:", packet.Message
        RETURN 1
    END IF
    LET copy AS POINTER TO BYTE[] = NEW BYTE[16]
    LET copied AS INTEGER OR Error = packet.CopyTo(copy, 16)
    IF copied IS INTEGER THEN
        PRINT "received", packet.Size(), "bytes, truncated:", packet.WasTruncated()
        PRINT "payload:", copy[0], copy[1], copy[2]
    END IF

    sender.Close()
    receiver.Close()
    RELEASE datagram
    RELEASE copy
    RETURN 0
END FUNCTION
```

```
received 3 bytes, truncated: FALSE
payload: 1 2 3
```

## ICMP Echo

An ICMP Echo request asks a host to answer, and is the usual first test of whether a machine is reachable at all. `Net.Ping` sends one ICMP Echo to a parsed address. Timeout, unreachable host, and missing ICMP permission are distinct errors, and a host without ICMP permission still allows every other `HOST.Net` operation.

```basic
IMPORT HOST.Net AS Net

FUNCTION Start() AS INTEGER
    LET target AS Net.Address OR Error = Net.Address.Parse("127.0.0.1")
    IF target IS Error THEN
        RETURN 1
    END IF
    LET reply AS Net.PingReply OR Error = Net.Ping(target, 1000)
    IF reply IS Error THEN
        // Timeout, unreachable, and missing ICMP permission are distinct errors.
        PRINT "ping failed:", reply.Code, reply.Message
        RETURN 1
    END IF
    PRINT "reply from", reply.Address().ToString(), "in", reply.RoundTripMicroseconds(), "us"
    RETURN 0
END FUNCTION
```

```
reply from 127.0.0.1 in <round-trip time> us
```

## HTTP with `BNWeb`

HTTP, the protocol of the Web, is a text protocol layered on TCP, and implementing it by hand on raw sockets is both laborious and easy to get subtly wrong. Programs use the `BNWeb` module instead. `BNWeb` builds on `HOST.Net` to provide a bounded request and response model, routing, filters, and local HTTP/1.1, HTTP/2, and HTTPS server adapters:

```basic
IMPORT BNWeb AS Web
```

Its servers, routes, cookies, sessions, and static file serving are described in [Appendix H](appendix_h_bnweb.md).

## Interpreter and Compiler Support

Every example in this chapter runs under `bni run`. `bnc` compiles the TCP, UDP, `CIDR`, and `Ping` examples, and rejects the remaining network methods with `TARGET_UNSUPPORTED_HOST`: the `Address` predicates (`IsIPv4`, `IsLoopback`, …) and `TCPStream.SetTimeouts`, `ShutdownRead`, and `ShutdownWrite`. When `bnc` refuses an operation, run the program with `bni` instead.

## Summary

`HOST.Net` gives a program typed and bounded access to the network. Addresses and networks are parsed and validated before use, and `Net.Resolve` is the only operation that turns a host name into addresses. TCP provides ordered, reliable streams over connections; UDP provides independent datagrams; ICMP Echo tests reachability. Every operation that waits takes a timeout and returns `T OR Error`, so an unresponsive peer becomes an error the program handles rather than a program that hangs. HTTP is built on top of these primitives by the `BNWeb` module.

## References

- Deering, S., and Hinden, R. (2017). *Internet Protocol, Version 6 (IPv6) Specification*. RFC 8200. https://www.rfc-editor.org/rfc/rfc8200
- Eddy, W. (Ed.) (2022). *Transmission Control Protocol (TCP)*. RFC 9293. https://www.rfc-editor.org/rfc/rfc9293
- Mockapetris, P. (1987). *Domain Names — Concepts and Facilities*. RFC 1034. https://www.rfc-editor.org/rfc/rfc1034
- Postel, J. (1980). *User Datagram Protocol*. RFC 768. https://www.rfc-editor.org/rfc/rfc768
- Postel, J. (1981a). *Internet Protocol*. RFC 791. https://www.rfc-editor.org/rfc/rfc791
- Postel, J. (1981b). *Internet Control Message Protocol*. RFC 792. https://www.rfc-editor.org/rfc/rfc792

---

[Next: Concurrency →](15_concurrency.md)
