---
title: BACnet
summary: The building-automation protocol; objects discovered, read and written over BACnet/IP UDP 47808 or MS/TP serial.
---

## What it is and where it sits

BACnet is the standard protocol for building automation: HVAC, lighting, access
control, energy metering and fire and life-safety systems. A BACnet device is a
collection of objects (analog and binary inputs, outputs and values, schedules,
trend logs, the device object itself), each with properties such as
present-value. Devices announce themselves with I-Am and are found with Who-Is
and Who-Has; properties are read and written with read-property and
write-property. BACnet increasingly shares a network with industrial control, so
an OT incident often reaches into it. On the Purdue model it spans the building
systems' own supervisory and field layers.

## Ports

UDP 47808 for BACnet/IP (BVLC); MS/TP over RS-485 for serial field buses. A BBMD
(broadcast management device) forwards broadcasts between BACnet/IP subnets.

## What it can do, and what that means

- **Discovery** (Who-Is, Who-Has, I-Am, I-Have) enumerates devices and objects,
  usually by broadcast.
- **Reads** (read-property, read-property-multiple) return object values and
  configuration.
- **Writes** (write-property, write-property-multiple) change present-values,
  set points and settings a controller acts on; a priority array decides which
  writer wins.
- **Control** services restart devices (reinitialize-device), control
  communication (device-communication-control) and change alarm and schedule
  configuration.

A write or control service is the [writes](../../lifecycle/wire-classes.md)
class: the engineer present, the exact object, property and value agreed,
announced to the site. Changing a damper, a valve or a safety set point has
physical effect.

## What to watch for in a capture

- write-property to objects from a host that should only read.
- reinitialize-device or device-communication-control, which restart or silence
  devices.
- A flood of Who-Is broadcasts, which looks like enumeration.
- Changes to alarm or schedule objects, which can suppress a response.

## Wireshark display filters

```text
# All BACnet application messages
bacapp
# Who-Is (8) and I-Am (0)
bacapp.unconfirmed_service == 8 || bacapp.unconfirmed_service == 0
# readProperty (12) and readPropertyMultiple (14)
bacapp.confirmed_service in {12,14}
# writeProperty (15) and writePropertyMultiple (16)
bacapp.confirmed_service in {15,16}
# deviceCommunicationControl (17) and reinitializeDevice (20)
bacapp.confirmed_service in {17,20}
# The BACnet/IP virtual link layer (BVLC), including forwarded broadcasts
bvlc
```

## SnapshOT tools that speak or decode it

- [BACpypes3](../protocols/bacpypes3.md): discover devices and read or write
  object properties, with exact control.
- [BAC0](../protocols/bac0.md): the same, in fewer lines, for interactive use.
- [nmap](../recon/nmap.md) (`bacnet-info`, and [Redpoint
  NSE](../recon/redpoint-nse.md) `BACnet-discover-enumerate` when the vendor
  layer is present): identify BACnet devices.
- [tshark](../traffic/tshark.md) and [Wireshark](../traffic/wireshark.md):
  capture and decode BACnet.

## ATT&CK for ICS techniques that ride on it

- [Discovery](../../lifecycle/attack-ics/discovery.md): Remote System Discovery:
  Broadcast Discovery (T0846.002), Remote System Information Discovery (T0888).
- [Collection](../../lifecycle/attack-ics/collection.md): Monitor Process State
  (T0801).
- [Impair Process Control](../../lifecycle/attack-ics/impair-process-control.md):
  Modify Parameter (T0836).
- [Inhibit Response Function](../../lifecycle/attack-ics/inhibit-response-function.md):
  Device Restart/Shutdown (T0816), Modify Alarm Settings (T0838), Alarm
  Suppression (T0878).

## Upstream specification

- [BACnet (ASHRAE)](http://www.bacnet.org/): ASHRAE Standard 135, the object
  model and the BACnet/IP annex.
