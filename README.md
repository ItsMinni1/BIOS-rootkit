# Antigravity Bootkit Demonstration

This project is an educational demonstration of an MBR (Master Boot Record) bootkit. It is written in x86 Assembly and designed to run in a virtualized environment.

## Features

- **Custom Boot Splash**: Overrides the standard BIOS boot process with a custom interface.
- **Interrupt Hooking**: Demonstrates how a bootkit can intercept hardware events by hooking the keyboard interrupt (`INT 09h`).
- **Real-Mode Execution**: Operates in 16-bit real mode, providing direct access to BIOS interrupts and system memory.
- **Emergency Reboot**: Includes a "panic" key ('R') that triggers a far jump to `0xFFFF:0000` to reboot the system.

## How it Works

1. **Stage 1 (MBR)**: The BIOS loads the first 512 bytes of the disk into memory at address `0x7C00` and jumps to it.
2. **Setup**: The bootkit initializes the segment registers and sets up a stack.
3. **Payload Loading**: It uses BIOS Disk Services (`INT 13h`) to read the second sector of the disk into memory at `0x8000`.
4. **Hooking**: It patches the Interrupt Vector Table (IVT) to hook the keyboard interrupt (`INT 09h`).
5. **Stage 2 (Intrusion)**: It jumps to `0x8000` to execute the Stage 2 payload, which displays the final intrusion message and establishes full control over the environment.

## Prerequisites

- `nasm`: The Netwide Assembler.
- `qemu`: For running the bootkit in a virtual machine.

## Usage

### Build the bootkit
```bash
make
```

### Run in QEMU
```bash
make run
```

## Safety Note

This code is strictly for **educational purposes**. Never attempt to write this binary to a physical disk's MBR unless you are an expert and have a full backup of your system.
