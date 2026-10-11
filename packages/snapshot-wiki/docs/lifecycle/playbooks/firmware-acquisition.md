---
title: Firmware acquisition
summary: Image a device's firmware on the bench, compare it against known-good to find implants, and verify any reflash by reading it back.
phases: [eradication, recovery]
tactics: [persistence, impair-process-control]
---

Firmware is where persistence hides: an implant in a controller's flash survives a
restart and a logic reload, and a modified firmware changes what the device does
to the process. Acquiring and comparing firmware belongs in
[eradication](../phases/eradication.md), and verifying a clean device belongs in
[recovery](../phases/recovery.md). This is bench work on hardware the engineer has
released from service, under the physical-access rules in the
[rules of engagement](../rules-of-engagement.md): a live, in-service controller is
never clipped or halted.

## Before you start

- The engineer present, and the device, board or chip released from service (a
  maintenance window, a spare, or a unit removed for the purpose). Never a running
  controller.
- The physical path confirmed: power, voltage levels and pinout for a serial,
  JTAG/SWD or SPI connection.
- A known-good firmware image to compare against, if the vendor or a clean sister
  device can provide one.

## Procedure

1. **Release and set up the hardware.** With the engineer, work on the released
   device or a spare, and confirm how it is powered and connected before anything
   is clamped on.
   - *Record:* the device, the board, the chip and the acquisition method chosen.
   - *Go/no-go:* if the only target is a live, in-service device, stop; acquisition
     waits for a window or a spare.

2. **Acquire a first read-only image.** Depending on the path: dump SPI flash with
   [flashrom](../../tools/firmware/flashrom.md), read memory over JTAG/SWD with
   [OpenOCD](../../tools/firmware/openocd.md), or pull an image through a
   [serial console](../../tools/firmware/minicom.md) and a bootloader. Read only.
   - *Record:* the chip, the method and the exact command.

3. **Hash it and confirm it is stable.** Hash the dump into the case `SHA256SUMS`
   at once, then take a second independent read and confirm the two match, so the
   acquisition itself is trustworthy.
   - *Go/no-go:* if two reads disagree, the acquisition is not stable; fix the
     connection before relying on the image.

4. **Analyze and compare.** Use [binwalk](../../tools/firmware/binwalk.md) to
   identify and extract the image's contents, and compare it against the
   known-good image: changed boot code, added services, unexpected files.
   - *Record:* every difference from known-good, with offsets.
   - *Looks for:* [Persistence](../attack-ics/persistence.md), Modify Firmware
     (T1693, with its sub-techniques System Firmware, T1693.001, and Module
     Firmware, T1693.002).

5. **Reflash to known-good only with the engineer.** If eradication requires it,
   the engineer directs a reflash; [flashrom](../../tools/firmware/flashrom.md) or
   [OpenOCD](../../tools/firmware/openocd.md) writes the known-good image. Keep the
   pre-reflash dump as evidence. This is a [writes](../wire-classes.md) action.
   - *Looks for:* [Impair Process Control](../attack-ics/impair-process-control.md):
     restoring the firmware the process depends on.

6. **Verify by reading back.** After any write, read the firmware again and confirm
   its hash matches the known-good image.
   - *Record:* the read-back hash against the expected one.

7. **Confirm it runs, in recovery.** Return the device to service with the engineer
   and watch it with a [capture](passive-baseline.md) to confirm it boots, runs the
   expected logic and is polled only by the expected hosts.

## Done when

- A hashed, stable firmware image exists, and its differences from known-good are
  documented.
- Any reflash was directed by the engineer and verified by a matching read-back
  hash.
- In recovery, the device runs the expected firmware and logic and communicates
  normally.

## Related pages

- [Protocol interrogation](protocol-interrogation.md): when the change is a parameter, not firmware.
- [Rules of engagement](../rules-of-engagement.md): the serial, JTAG and SPI physical rules.
- [Evidence handling](../evidence-handling.md): hashing dumps and keeping the pre-reflash copy.
