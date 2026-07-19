# Hardware Deep Dive

**Project:** Project TITAN  
**Category:** Hardware  
**Module:** Module 1  
**Created:** July 12, 2026  
**Last Updated:** July 12, 2026  

---

## Purpose

This document provides a technical overview of the hardware used as the primary server for Project TITAN.

The system will be used to learn and practice:

- Linux server administration
- Virtualization
- Containers
- Networking
- Storage management
- Monitoring
- Cybersecurity
- DevOps

---

## System Overview

| Property | Value |
|---|---|
| Manufacturer | Lenovo |
| Model | ThinkCentre M70q Gen 2 |
| Form Factor | Tiny, approximately 1 liter |
| Processor | Intel Core i5-11400T |
| Installed Memory | 32 GB DDR4 |
| Primary Storage | 512 GB Samsung NVMe SSD |
| Current Operating System | Windows 11 Pro |
| Planned Role | Project TITAN primary homelab server |

The ThinkCentre M70q Gen 2 uses the Intel B560 chipset and has a Tiny 1-liter form factor. :contentReference[oaicite:0]{index=0}

---

# Processor

## General Specifications

| Property | Value |
|---|---|
| Processor | Intel Core i5-11400T |
| Generation | 11th Generation Intel Core |
| Architecture | x86-64 |
| Code Name | Rocket Lake |
| Lithography | 14 nm |
| Socket | FCLGA1200 |
| Cores | 6 |
| Threads | 12 |
| Base Frequency | 1.30 GHz |
| Maximum Turbo Frequency | 3.70 GHz |
| Cache | 12 MB Intel Smart Cache |
| Bus Speed | 8 GT/s |

The i5-11400T contains 6 cores and 12 threads, with a 1.30 GHz base frequency and a maximum turbo frequency of 3.70 GHz. :contentReference[oaicite:1]{index=1}

---

## Thermal Design Power

| Property | Value |
|---|---|
| Standard TDP | 35 W |
| Configurable TDP-Down | 25 W |
| TDP-Down Base Frequency | 1.00 GHz |
| Maximum Junction Temperature | 100°C |

The processor has a standard TDP of 35 watts and can be configured down to 25 watts by supported system firmware. :contentReference[oaicite:2]{index=2}

### Important Note

TDP is not the same as the computer's total electrical consumption.

Actual system power consumption depends on:

- CPU utilization
- Memory utilization
- Connected storage
- USB devices
- Network activity
- Cooling fan speed
- BIOS power settings

The exact idle and load consumption of this specific computer should later be measured using a power meter.

---

# Virtualization Support

| Technology | Supported |
|---|---|
| Intel Virtualization Technology — VT-x | Yes |
| Intel Virtualization Technology for Directed I/O — VT-d | Yes |
| Extended Page Tables — EPT | Yes |
| Intel Hyper-Threading | Yes |
| 64-bit Instruction Set | Yes |

The i5-11400T officially supports VT-x, VT-d, and Extended Page Tables. :contentReference[oaicite:3]{index=3}

## What These Technologies Do

### Intel VT-x

VT-x allows the processor to run virtual machines more efficiently.

This technology will be useful for:

- Proxmox VE
- Linux virtual machines
- Windows virtual machines
- Cybersecurity laboratories
- Test environments

### Intel VT-d

VT-d allows compatible hardware devices to be assigned more directly to virtual machines.

Potential uses include:

- Network interface passthrough
- Storage controller passthrough
- USB controller passthrough
- Specialized virtual machines

Support from the processor does not automatically guarantee that every passthrough configuration will work. The motherboard, chipset, BIOS, operating system, and hypervisor must also support the feature.

### Extended Page Tables

EPT provides hardware-assisted memory virtualization.

This reduces virtualization overhead and improves virtual-machine performance.

---

# PCI Express

| Property | Value |
|---|---|
| PCI Express Revision | PCIe 4.0 |
| Maximum CPU PCIe Lanes | 20 |
| Supported CPU Configurations | Up to 1×16 + 1×4, 2×8 + 1×4, or 1×8 + 3×4 |

The processor supports PCI Express 4.0 and provides up to 20 processor PCIe lanes. :contentReference[oaicite:4]{index=4}

## Important Limitation

The processor's maximum of 20 PCIe lanes does not mean the M70q Gen 2 exposes 20 usable expansion lanes.

This Tiny computer does not contain a normal desktop PCIe expansion slot. Its internal expansion is primarily provided through:

- One M.2 slot for an NVMe SSD
- One M.2 slot for the wireless network card
- One internal 2.5-inch SATA drive bay

Lenovo officially lists two M.2 slots, but one is intended for WLAN and the other for an SSD. :contentReference[oaicite:5]{index=5}

---

# Memory

## Processor Memory Support

| Property | Processor Capability |
|---|---|
| Maximum Memory | 128 GB |
| Memory Type | DDR4-3200 |
| Memory Channels | 2 |
| Maximum Memory Bandwidth | 50 GB/s |
| ECC Support | No |

Intel specifies that the processor itself can address up to 128 GB of DDR4-3200 memory. :contentReference[oaicite:6]{index=6}

## Computer Memory Support

| Property | Lenovo System Limit |
|---|---|
| Official Maximum Memory | 64 GB |
| Memory Slots | 2 DDR4 SO-DIMM slots |
| Channel Support | Dual-channel |
| Supported Lenovo Speeds | DDR4-2666, DDR4-2933 and DDR4-3200 |
| Current Installed Memory | 32 GB at 2667 MHz |

Lenovo officially validated this system for up to 64 GB of DDR4-2933 memory through two SO-DIMM slots. :contentReference[oaicite:7]{index=7}

## Why Intel and Lenovo Show Different Maximums

The processor can technically address up to 128 GB, but the complete Lenovo system was officially validated for up to 64 GB.

For this homelab, the practical documented maximum should therefore be considered:

> **64 GB of RAM**

The current 32 GB configuration is sufficient to begin running multiple containers and several lightweight virtual machines.

---

# Integrated Graphics

| Property | Value |
|---|---|
| GPU | Intel UHD Graphics 730 |
| Execution Units | 24 |
| Base Graphics Frequency | 350 MHz |
| Maximum Dynamic Frequency | 1.20 GHz |
| Intel Quick Sync Video | Yes |
| Maximum Supported Displays | 3 |
| 4K Support | Yes, up to 60 Hz depending on output |

The i5-11400T includes Intel UHD Graphics 730 and supports Intel Quick Sync Video. :contentReference[oaicite:8]{index=8}

## Intel Quick Sync Video

Quick Sync is Intel's hardware-accelerated video encoding and decoding technology.

Potential Project TITAN uses include:

- Jellyfin video transcoding
- Media conversion
- Video streaming
- Reducing CPU usage during supported media workloads

Quick Sync may make this mini PC especially useful as a future media server.

---

# Internal Storage

## NVMe Storage

| Property | Value |
|---|---|
| SSD Slots | One M.2 slot intended for an SSD |
| Supported Form Factors | M.2 2242 and M.2 2280 |
| Interface | PCIe NVMe |
| Lenovo-Validated Maximum Capacity | Up to 2 TB |
| Current SSD | Samsung 512 GB NVMe SSD |
| Current SSD Model | Samsung MZVLB512HBJQ-000L7 |

Lenovo officially documents support for one M.2 NVMe SSD, validated in capacities up to 2 TB. :contentReference[oaicite:9]{index=9}

## Important Correction

The system does not officially provide two general-purpose NVMe SSD slots.

It contains:

1. One M.2 slot for an NVMe SSD
2. One M.2 slot for the Wi-Fi and Bluetooth card

The wireless M.2 slot should not be documented as a second NVMe storage slot.

---

## Internal SATA Storage

| Property | Value |
|---|---|
| Internal Drive Bay | One 2.5-inch bay |
| Interface | SATA 6 Gb/s |
| Lenovo-Validated HDD Capacity | Up to 1 TB |
| Current Internal SATA Drive | None |

The M70q Gen 2 supports one internal 2.5-inch SATA drive using a SATA 6 Gb/s interface. Lenovo's original tested configurations included drives up to 1 TB. :contentReference[oaicite:10]{index=10}

### SATA Revision

A SATA speed of 6 Gb/s corresponds to:

> **SATA Revision 3.x**

The official Lenovo specification describes the interface by its 6 Gb/s speed rather than naming the revision directly.

---

# External Hard Drives

## Available Drives

| Drive | Capacity | Form Factor | Interface | Planned Use |
|---|---:|---|---|---|
| HDD 1 | 2 TB | To be confirmed | SATA | Primary data or backup |
| HDD 2 | 2 TB | To be confirmed | SATA | Backup or redundant copy |

## Required Hardware

A powered USB enclosure or docking station is still required.

Before purchasing the enclosure, the following information must be confirmed:

- Whether the drives are 2.5-inch or 3.5-inch
- Whether both drives need to remain connected simultaneously
- Whether independent drive access is required
- Whether the enclosure supports UASP
- Whether the enclosure has its own power adapter
- Whether hardware RAID is included
- Whether the drives will be managed individually or through software

### Important Storage Rule

RAID is not a backup.

Even if both drives are later mirrored, important information should still have another copy stored on a separate device or location.

---

# Networking

## Wired Ethernet

| Property | Value |
|---|---|
| Controller | Intel Ethernet Connection I219-V |
| Port | One RJ-45 |
| Maximum Speed | 1 Gigabit per second |
| Wake-on-LAN | Supported |

The integrated Ethernet interface is Gigabit Ethernet and uses an Intel I219-V controller. :contentReference[oaicite:11]{index=11}

### Recommended Homelab Connection

The server should eventually use Ethernet instead of Wi-Fi whenever possible because Ethernet generally provides:

- More consistent latency
- Greater connection stability
- Easier server troubleshooting
- Better suitability for storage transfers
- More reliable remote administration

---

## Wireless Networking

The system may contain one of several wireless configurations originally offered by Lenovo:

- Intel Wi-Fi 6 AX201 with Bluetooth 5.1
- Intel Wireless-AC 9560 with Bluetooth 5.1
- Realtek RTL8822CE with Bluetooth 5.0

Lenovo offered multiple Wi-Fi configurations for the M70q Gen 2, so the exact adapter installed in this machine must still be confirmed from Windows. :contentReference[oaicite:12]{index=12}

### Current Known Information

- A Wi-Fi adapter is installed.
- An external Wi-Fi antenna was included.
- The exact Wi-Fi card model is not yet confirmed.
- The exact Bluetooth version is not yet confirmed.

---

# USB and External Connectivity

## Front Ports

- One USB-A 3.2 Gen 2 port
- One USB-C 3.2 Gen 1 port
- One 3.5 mm headphone and microphone combination jack

## Rear Ports

- Two USB-A 3.2 Gen 1 ports
- Two USB-A 3.2 Gen 2 ports
- One RJ-45 Gigabit Ethernet port
- One HDMI output
- One DisplayPort output
- One configurable optional port, depending on the original system configuration

Lenovo lists USB speeds of 5 Gb/s for USB 3.2 Gen 1 and 10 Gb/s for USB 3.2 Gen 2. :contentReference[oaicite:13]{index=13}

## Relevance to External Storage

For the future HDD enclosure, a USB 3.2 port should be used instead of an older USB 2.0 connection.

A USB enclosure supporting UASP is preferred because it can provide more efficient storage communication than traditional USB mass-storage operation.

---

# Video Outputs

| Output | Quantity |
|---|---:|
| HDMI | 1 |
| DisplayPort | 1 |
| Optional Configurable Video Port | Configuration-dependent |

The system can support up to three independent displays when equipped with the appropriate optional video output. :contentReference[oaicite:14]{index=14}

For normal server operation, a monitor will mainly be needed during installation and troubleshooting. Routine administration should later be performed remotely through SSH or a web management interface.

---

# Power System

| Property | Value |
|---|---|
| CPU TDP | 35 W |
| Supported Lenovo Power Adapters | 65 W or 135 W, depending on configuration |
| Current Adapter | To be confirmed |
| UPS | Not currently available |

Lenovo offered the M70q Gen 2 with either a 65-watt or 135-watt external power adapter, depending on configuration. :contentReference[oaicite:15]{index=15}

## What Is a UPS?

UPS means:

> **Uninterruptible Power Supply**

A UPS contains a battery that can temporarily power the server during an electrical outage.

It can help protect against:

- Sudden shutdowns
- Filesystem corruption
- Interrupted backups
- Data loss
- Short power interruptions
- Some voltage fluctuations

A UPS is not required to begin Project TITAN, but it is a recommended future upgrade before the server stores important data.

---

# Physical Specifications

| Property | Value |
|---|---|
| Form Factor | Tiny, approximately 1 liter |
| Dimensions | 179 × 182.9 × 36.5 mm |
| Approximate Weight | 1.25 kg / 2.76 lb |
| Internal 2.5-inch Bay | One |
| M.2 Slots | Two total: one WLAN and one SSD |

These measurements and expansion details come from Lenovo's official product specification. :contentReference[oaicite:16]{index=16}

---

# Homelab Suitability

## Strengths

- Six CPU cores and twelve threads
- Hardware virtualization support
- VT-d support
- 32 GB of installed memory
- Upgradeable to 64 GB according to Lenovo
- Low-power 35-watt processor
- Intel Quick Sync Video
- Gigabit Ethernet
- Internal NVMe storage
- Internal 2.5-inch SATA support
- Small physical footprint
- Multiple high-speed USB ports

## Limitations

- Only one official M.2 NVMe SSD slot
- No standard desktop PCIe expansion slot
- Only Gigabit Ethernet
- Limited internal storage space
- External storage requires USB enclosures
- No built-in redundant power supply
- No current UPS
- External USB disks may be less reliable than a dedicated NAS or direct-attached internal storage

---

# Recommended Initial Role

The system is suitable for beginning Project TITAN with:

- Proxmox VE or Ubuntu Server
- Linux virtual machines
- Docker containers
- Internal DNS
- Pi-hole or AdGuard Home
- PostgreSQL
- Redis
- Nginx Proxy Manager
- Grafana
- Prometheus
- Uptime Kuma
- WireGuard
- Small cybersecurity laboratories
- Personal web applications
- Jellyfin with hardware-accelerated transcoding
- Automated backups

---

# Information Still to Confirm

The following information must be verified later:

- Exact machine type and model number
- BIOS version
- Current BIOS virtualization settings
- Exact RAM manufacturer and module configuration
- Whether the RAM is installed as 2 × 16 GB or 1 × 32 GB
- Exact Wi-Fi card model
- Exact Bluetooth version
- Current power adapter wattage
- Ethernet MAC address
- SSD health
- HDD form factors
- HDD manufacturers and model numbers
- HDD health
- Available internal SATA cable and drive caddy
- Exact optional rear port installed
- Actual idle and load power consumption

---

# Final Assessment

The Lenovo ThinkCentre M70q Gen 2 is a strong entry-level homelab server.

Its Intel Core i5-11400T provides enough cores, threads, virtualization support, and media acceleration for a mixed environment containing virtual machines, containers, network services, monitoring tools, development projects, and selected cybersecurity laboratories.

The main limitations are storage expansion and the single Gigabit Ethernet interface. These limitations do not prevent the system from serving as the primary learning platform for Project TITAN.

---

# Sources

- Intel Core i5-11400T official processor specifications
- Lenovo ThinkCentre M70q Gen 2 official Product Specifications Reference
