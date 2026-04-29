Place the latest OTA application binary here.

Default backend settings expect:

- file: `SmartShev-firmware.bin`
- public URL: `/static/firmware/SmartShev-firmware.bin`

Build the firmware app binary from the full ESP-IDF project, then copy the app
`.bin` file into this directory. The bootloader and partition table binaries
are not used for OTA updates.
