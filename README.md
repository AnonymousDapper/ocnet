# OC Network Stack Reference

https://en.wikipedia.org/wiki/List_of_IP_protocol_numbers
http://www.tcpipguide.com/free/t_IPDatagramGeneralFormat.htm

## Addressing

OCNet addresses are 2 bytes composed of 4 groups of 4 bits in hex format (eg. `4.d.e.5`).

Addresses are stored BE (big-endian).

### Reservations

- x.x.x.0
- x.x.x.f


## Layers

### L1

Abstract `Interface` that encapsulates different components into one API (tunnel, loopback, modem, wireless modem, relay)

Common methods:

	write
	read
	up
	down


Also handles ethernet frames

0 `[magic][src mac][dest mac][data]`

	Magic:		     1 (E)

	Source MAC:      36
		OCs UUID4

	Destination MAC: 36
		OCs UUID4

Notes:
	`modem.maxPacketSize()` for max bytes in packet

	MTU = (maxPacketSize - 2) - 73

### L2

Handles encoding/decoding of link frames




#### Frame Format
	
Roughly follows the IP datagram

0 `[magic][version][ttl][protocol][checksum][src][dst][data]` 10

	Magic:			 1 (I)

	Version: 		 1 (1)

	TTL: 			 1

	Protocol:		 1

	Checksum:		 2

		Magic + Version + TTL + Protocol

	Source MAC:		 2
		OC's UUID4 component address


	Destination MAC: 2
		OC's UUID4 component address


MTU = L1 MTU - 10

### L3

Routing uses IP protocol number 250 and/or operates on port 89, but functions somewhat like RIP

This layer also provides address translation between OCNet addresses and OC component addresses according to the current routing table.

Communication:

	Hello - broadcast on first load

	Table - sent on receipt of `Hello`, contains the recipient's routing table

Routing Table:

	OCNet Address
	OC UUID Address
	Hop Count - max of 15

Route Timers:

	Invalid: 180s - mark hop count as 16 (unreachable)
	Flush: 240s - remove route from table

Hello packet:
	
0 `[magic]H` 2
	
	Magic: 1 (R)

Table packet:

0 `[magic]T[sender address][data]0`

	Magic:   1 (R)

	Address: 2



### L4

Transport protocols

- TCP

- UDP

### L5

TLS-like encryption handshake

### L6

Level 6 is where compression (if applicable) and name resolution handled

### L7

Application Layer
