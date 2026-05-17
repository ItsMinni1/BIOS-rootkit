# Master Boot Record (MBR) Bootloader & Bootkit Explanation
This document provides a highly detailed, line-by-line explanation of the educational MBR bootkit implementation (`boot.asm`) used for the Computer Organization & Assembly Language course. It covers the core real-mode concepts, CPU architecture registers, BIOS interrupts, and low-level memory operations involved in the execution of the boot sector.

---

## 📖 Key Architectural Concepts

Before diving into the code, it is essential to understand the architectural context of the 8086 CPU and early PC boot process.

### 1. 16-Bit Real Mode & Segmented Memory
Upon booting, x86 processors start in **16-Bit Real Mode**. In this mode, the CPU can only access up to 1 MB of memory ($2^{20}$ bytes). To refer to physical memory using 16-bit registers, the processor uses **Segmented Memory Architecture**:
$$\text{Physical Address} = (\text{Segment} \times 16) + \text{Offset} = (\text{Segment} \ll 4) + \text{Offset}$$

*   `CS` (Code Segment): Points to the segment containing the currently executing code.
*   `DS` (Data Segment): Points to the default segment for variable/data access.
*   `ES` (Extra Segment): Used for string and memory operations as a destination segment.
*   `SS` (Stack Segment): Points to the segment storing the stack.
*   `SP` (Stack Pointer): Points to the top of the current stack frame.

### 2. The Boot Process & MBR Constraints
1.  When the computer is powered on, the BIOS initializes the hardware and runs the POST (Power-On Self-Test).
2.  The BIOS looks for a bootable drive and reads the very first sector (Sector 1, Cylinder 0, Head 0)—known as the **Master Boot Record (MBR)**.
3.  The BIOS expects this sector to be exactly **512 bytes** in size and must end with the boot signature **`0xAA55`** at offsets 510–511. If the signature is present, the BIOS copies these 512 bytes into physical memory address **`0x07C00`** and jumps execution to `0000h:7C00h` (or `07C0h:0000h`).

### 3. Self-Relocation (The `start_mover` Pattern)
A standard MBR is loaded at `0x07C00`. However, most operating system kernels or Stage 2 loaders also expect to be loaded into the low-memory area near `0x07C00`. To prevent the next stage from overwriting our bootloader in active memory, we perform **Self-Relocation**:
*   Copy the entire 512-byte boot sector from the original address (`0x07C00`) to a safe location in high memory (`0x90000` / `0x9000:0000`).
*   Perform a **Far Jump** (`jmp 0x9000:relocated`) to transfer active CPU execution to the newly copied block in high memory.
*   Once relocated, the memory at `0x07C00` is now completely free to safely load the Stage 2 payload without memory collisions.

---

## 🔍 Line-by-Line Code Walkthrough

Below is a granular, functional analysis of every single instruction block in `boot.asm`.

### Phase 1: Setup & Initialization
```nasm
[bits 16]           ; Use 16-bit real mode
[org 0]             ; Use relative offsets
```
*   **`[bits 16]`**: Tells the assembler (NASM) to generate 16-bit machine code instructions compatible with real mode.
*   **`[org 0]`**: Defines the origin offset. By setting it to `0`, all labels in the MBR are calculated as offsets from the start of the data/code segment rather than absolute physical addresses. This enables segment-agnostic addressing.

```nasm
start:
    cli
    mov ax, 0x07C0
    mov ds, ax
    mov es, ax
    cli             ; Clear interrupts
    mov [boot_drive], dl ; Save boot drive index
```
*   **`cli`**: *Clear Interrupt Flag*. Temporarily disables maskable hardware interrupts (like keyboard inputs or system timers) to prevent an external interrupt from disrupting the setup of the segment registers.
*   **`mov ax, 0x07C0`** & **`mov ds, ax`** / **`mov es, ax`**: We cannot load segment registers (`DS`, `ES`) directly with immediate values in x86. We must load the value into a general-purpose register (`AX`) first, and then transfer it to `DS` and `ES`. This aligns our data and extra segments to point directly to `0x07C0` (where the MBR is loaded).
*   **`mov [boot_drive], dl`**: Upon booting, the BIOS stores the active boot drive index (e.g., `0x00` for floppy, `0x80` for the first hard disk) in the `DL` register. We save this value into our memory variable `boot_drive` so we can access it later to load the payload from the correct disk.

---

### Phase 2: Self-Relocation (`start_mover`)
```nasm
    ; --- RESEARCH IMPLEMENTATION: start_mover (Relocation) ---
    mov ax, 0x07C0  ; Current location segment
    mov ds, ax
    xor si, si      ; Source offset 0
    
    mov ax, 0x9000  ; Destination segment
    mov es, ax
    xor di, di      ; Destination offset 0
```
*   **`mov ax, 0x07C0`** / **`mov ds, ax`**: Aligns `DS` to point to the source segment (where the MBR currently resides).
*   **`xor si, si`**: Clears `SI` (Source Index) to `0` by XOR-ing it with itself. The source address is now set to `DS:SI` $\rightarrow$ `0x07C0:0000`.
*   **`mov ax, 0x9000`** / **`mov es, ax`**: Aligns `ES` (Extra Segment) to point to our destination segment in high memory.
*   **`xor di, di`**: Clears `DI` (Destination Index) to `0`. The destination address is now set to `ES:DI` $\rightarrow$ `0x9000:0000`.

```nasm
    mov cx, 256     ; 512 bytes
    rep movsw
```
*   **`mov cx, 256`**: Sets the loop counter `CX` to 256.
*   **`rep movsw`**: *Repeat Move String Word*. This single instruction copies a 16-bit word from `DS:SI` to `ES:DI`, increments both `SI` and `DI` by 2, decrements `CX`, and repeats this cycle until `CX = 0`. Copying 256 words successfully duplicates the entire 512-byte MBR sector into high memory (`0x9000:0000`).

```nasm
    ; Jump to the new location
    jmp 0x9000:relocated
```
*   **`jmp 0x9000:relocated`**: A **far jump** instruction. It immediately updates the CPU's Code Segment register (`CS`) to `0x9000` and the Instruction Pointer (`IP`) to the offset of the `relocated` label. Active execution transfers to the high-memory copy of our MBR.

---

### Phase 3: Segment Alignment in High Memory
```nasm
relocated:
    ; 2. Adjust Segments for High Memory
    mov ax, cs      
    mov ds, ax
    mov es, ax
    mov ss, ax      ; Use high memory for stack too
    mov sp, 0xFFFF  ; Stack at top of segment
    sti             ; Re-enable interrupts
```
*   **`mov ax, cs`** / **`mov ds, ax`** / **`mov es, ax`**: Since `CS` is now `0x9000`, we update both `DS` and `ES` to `0x9000` as well. This ensures all variable reads, screen writes, and string pointers now target the high memory block correctly.
*   **`mov ss, ax`** / **`mov sp, 0xFFFF`**: Creates a stack in high memory. The Stack Segment (`SS`) is set to `0x9000`, and the Stack Pointer (`SP`) is placed at `0xFFFF` (the very top of the segment). Since the stack grows downwards in memory, it has plenty of safe space before it reaches our bootloader code (which sits at offset `0x0000`).
*   **`sti`**: *Set Interrupt Flag*. Re-enables hardware interrupts now that our stack and registers are safely configured.

---

### Phase 4: Setting Video Mode & Outputting Visual Steps
```nasm
    ; 2. Visual Excellence: Clear Screen & Set Video Mode
    mov ax, 0x0003  ; Set 80x25 Color Text Mode
    int 0x10
```
*   **`mov ax, 0x0003`**: Triggers BIOS video service `AH=00h` (Set Video Mode) and selects mode `AL=03h` (80x25 standard color text mode).
*   **`int 0x10`**: Triggers BIOS video interrupt `0x10`. This initializes standard text rendering and clears any garbled text left behind by the BIOS startup.

```nasm
    ; Draw Header
    call clear_screen
    mov si, splash_msg
    mov bl, 0x0B    ; Light Cyan color
    call print_string_at_center
```
*   **`call clear_screen`**: Executes our helper subroutine to clean the screen buffer.
*   **`mov si, splash_msg`**: Places the memory address of the string "BIOS Bootkit" in the Source Index (`SI`) register.
*   **`mov bl, 0x0B`**: Sets the video attribute to Light Cyan text on a black background.
*   **`call print_string_at_center`**: Renders the splash header.

```nasm
    mov si, step1_msg
    mov bl, 0x07    ; White color
    mov dh, 10      ; Row 10
    call print_string
    call sleep
```
*   **`mov si, step1_msg`**: Points `SI` to `"Step 1: Relocation to high memory successful."`.
*   **`mov bl, 0x07`**: Sets text attribute to light grey on black (standard white).
*   **`mov dh, 10`**: Row number where the text will print.
*   **`call print_string`**: Displays the message on screen.
*   **`call sleep`**: Delays the bootloader for approximately **1 second** using system clock ticks, giving a clear step-by-step visual demonstration of MBR execution.

*(Note: The exact same pattern is repeated for `step2_msg` on Row 12 and `step3_msg` on Row 14).*

---

### Phase 5: Loading the Stage 2 Payload from Disk
```nasm
    ; 3. Load Stage 2 Payload (Sector 2)
    ; We use INT 13h, AH=02h to read from disk
    mov ah, 0x02    ; Read Sectors
    mov al, 1       ; Number of sectors to read
    mov ch, 0       ; Cylinder 0
    mov cl, 2       ; Sector 2
    mov dh, 0       ; Head 0
    mov dl, [boot_drive]
```
*   **`mov ah, 0x02`**: Selects BIOS low-level disk service `AH=02h` (Read Sectors from Drive).
*   **`mov al, 1`**: Specifies that we want to read exactly 1 sector (512 bytes).
*   **`mov ch, 0`** / **`mov cl, 2`**: Target disk address. Sector 1 is our MBR, so we read the immediate next sector: **Sector 2**, on Cylinder 0.
*   **`mov dh, 0`**: Head 0 of the drive.
*   **`mov dl, [boot_drive]`**: Retrieves the active boot drive index we saved during initialization.

```nasm
    xor ax, ax      ; Destination segment 0
    mov es, ax
    mov bx, 0x8000  ; Load offset (0000:8000)
    int 0x13
    jc .disk_error
```
*   **`xor ax, ax`** / **`mov es, ax`**: Sets the destination segment `ES` to `0000h`.
*   **`mov bx, 0x8000`**: Sets the destination offset `BX` to `0x8000`. The sector read from the disk will be copied to `ES:BX` $\rightarrow$ `0000h:8000h` (physical address `0x08000`).
*   **`int 0x13`**: Triggers BIOS disk interrupt `0x13`. The BIOS performs the raw disk sector read and transfers the 512-byte payload to memory.
*   **`jc .disk_error`**: *Jump if Carry*. BIOS disk interrupts set the Carry Flag (`CF = 1`) if the read failed (e.g. disk corruption or invalid sector). If `CF` is set, we jump immediately to the error handler.

---

### Phase 6: Executing the Payload
```nasm
    mov si, step4_msg
    mov bl, 0x0A    ; Light Green
    mov dh, 16
    call print_string
    call sleep

    mov si, final_msg
    mov bl, 0x0E    ; Yellow
    mov dh, 18
    call print_string
    call sleep
```
*   Prints `"Step 4: Payload loaded..."` in Light Green (`0x0A`) on Row 16, pauses, and then prints `"control taken hehe >:)"` in Yellow (`0x0E`) on Row 18.

```nasm
    ; 4. Jump to Payload
    jmp 0x0000:0x8000
```
*   **`jmp 0x0000:0x8000`**: A far jump. It changes `CS` to `0x0000` and `IP` to `0x8000` (where the Stage 2 payload was loaded). Control is successfully transferred from our MBR to the payload!

---

### Phase 7: Error Handling & Hang
```nasm
.disk_error:
    mov si, disk_err_msg
    mov bl, 0x0C    ; Red
    mov dh, 22
    call print_string
    jmp $           ; Hang
```
*   **`mov si, disk_err_msg`**: Points to `"DISK READ ERROR! Bootkit failed."`.
*   **`mov bl, 0x0C`**: Set text to Red on a black background.
*   **`jmp $`**: An infinite loop. `$` represents the address of the current instruction, so the CPU executes this jump repeatedly forever, hanging the computer in a safe state.

---

## 🛠️ Helper Subroutines & Procedures

```nasm
clear_screen:
    mov ax, 0x0600  ; Scroll up window (0 = clear)
    mov bh, 0x07    ; Light gray on black
    mov cx, 0x0000  ; Top-left (0,0)
    mov dx, 0x184F  ; Bottom-right (24,79)
    int 0x10
    ret
```
*   **`mov ax, 0x0600`**: Triggers scroll service `AH=06h`. Setting `AL=00h` scrolls the entire window up, effectively clearing it.
*   **`mov bh, 0x07`**: Sets the default background attribute to Light Grey on Black.
*   **`mov cx, 0x0000`** & **`mov dx, 0x184F`**: Defines the clear region from coordinates `(0,0)` (top-left) to `(79,24)` (bottom-right of an 80x25 character screen).
*   **`int 0x10`** & **`ret`**: Executes the clear via the BIOS interrupt and returns to the caller.

```nasm
print_string:
    mov dl, 10      ; Default column
.loop:
    lodsb
    or al, al
    jz .end
    push si
    mov ah, 0x02    ; Set cursor position
    mov bh, 0       ; Page 0
    int 0x10
    
    mov ah, 0x09    ; Write character/attribute
    mov cx, 1       ; One character
    int 0x10
    
    inc dl          ; Next column
    pop si
    jmp .loop
.end:
    ret
```
*   **`mov dl, 10`**: Sets the text indentation column to 10.
*   **`lodsb`**: *Load String Byte*. Loads the byte located at address `DS:SI` into the `AL` register, and automatically increments `SI` by 1 to point to the next character in memory.
*   **`or al, al`** & **`jz .end`**: Fast way to check if `AL` contains `0` (null terminator). If `AL = 0`, it means we reached the end of the string and we jump to return (`ret`).
*   **`mov ah, 0x02`** / **`int 0x10`**: Sets the cursor position to the coordinates specified by `DH` (Row) and `DL` (Column) on Page 0 (`BH=0`).
*   **`mov ah, 0x09`** / **`int 0x10`**: Writes the character inside `AL` with the visual color attributes specified inside `BL`. `CX=1` specifies to write it exactly once.
*   **`inc dl`**: Increments our column tracker `DL` by 1 so the next character prints in the adjacent column to the right.

```nasm
sleep:
    pusha
    mov ah, 0x00
    int 0x1A       ; CX:DX = ticks since midnight
    mov bx, dx     ; Save start tick
.wait:
    mov ah, 0x00
    int 0x1A       ; CX:DX = current ticks
    mov ax, dx
    sub ax, bx     ; Calculate difference (current - start)
    cmp ax, 18     ; 18 ticks ~ 1 second
    jb .wait       ; Wait if not enough ticks have elapsed
    popa
    ret
```
*   **`pusha`** & **`popa`**: Saves all 8 general-purpose registers to the stack at the start of the subroutine and restores them at the end. This prevents `sleep` from corrupting register states used by the main program.
*   **`mov ah, 0x00`** / **`int 0x1A`**: Calls BIOS time services. Retrieves the system clock tick counter since midnight, returning it in `CX:DX`.
*   **`mov bx, dx`**: Saves the starting tick state into `BX`.
*   **`.wait` loop**: Continually polls `INT 0x1A` to get the current tick count, subtracts the starting tick (`BX`) from the current tick (`DX`), and compares the difference with **18** (since the clock ticks at ~18.2 Hz, 18 ticks represents a stable 1-second delay). If less than 18 ticks have elapsed, the loop continues.

---

## 💾 Data & Boot Sector Structure

```nasm
splash_msg      db "BIOS Bootkit", 0
step1_msg       db "Step 1: Relocation to high memory successful.", 0
...
boot_drive       db 0
```
*   **`db`**: *Define Byte*. Allocates bytes of memory representing the ASCII text characters and terminates them with a `0` (null-terminator) for our print loop.
*   **`boot_drive db 0`**: Reserves a single byte initialized to `0` to store the boot drive index.

```nasm
times 510-($-$$) db 0   ; Padding to 510 bytes
dw 0xAA55               ; BIOS Boot Signature
```
*   **`$`** represents the current instruction address; **`$$`** represents the start address of the current section. Thus, `$-$$` calculates the exact compiled byte size of all our MBR code and data.
*   **`times 510-($-$$) db 0`**: Subtracts the compiled size from 510 and pads the remaining space with exact zero-bytes (`0`). This guarantees that our signature starts exactly at byte offset 510.
*   **`dw 0xAA55`**: *Define Word*. Writes the 16-bit word boot signature `0xAA55` at the end of the 512-byte sector, verifying to the BIOS that the drive is bootable.

---

## 🎯 Project Scope, Motivation & Challenges

### 1. Project Scope
The scope of this project is to construct a fully operational, educational, two-stage MBR (Master Boot Record) bootloader capable of running within standard x86 emulation platforms (such as QEMU and Emu8086).
* **Stage 1 (MBR Sector 1)**: Manages physical segment register normalization, dynamically performs self-relocation to high/adjacent memory to protect execution integrity, outputs step-by-step telemetry, implements a stable time delay loop, reads physical Sector 2 (Stage 2 payload) using BIOS Int `13h`, and securely transfers execution.
* **Stage 2 (Payload Sector 2)**: Receives control in real-mode memory, executes secondary tasks (in this educational case, printing completion messages), and halts the CPU safely.
* **Scope Exclusion**: To maintain high educational focus and focus on the fundamental concepts of low-level CPU control, advanced kernel transitions (like switching to Protected Mode or Long Mode) and unstable kernel-hooking structures (such as direct IVT hooking in memory) were deliberately kept out of the operational scope.

### 2. Motivation
The core motivation is to demystify the low-level interactions that occur between hardware firmware (BIOS) and software during the initial bootstrap process of a computer. 
By writing this project directly in assembly language without any operating system abstractions:
* It forces a deep, hands-on understanding of how the 8086 CPU coordinates segmented memory architecture (`CS`, `DS`, `ES`, `SS`, `SP`).
* It highlights how early BIOS services act as raw hardware drivers via software interrupts (such as direct video drawing or disk I/O).
* It provides a concrete, physical demonstration of security and system programming principles, specifically illustrating how "start-mover" self-relocation techniques prevent code collision in real-mode memory layouts.

### 3. Implementation Challenges
Several critical technical challenges were encountered and successfully resolved during the implementation of this project:

#### A. The MBR 512-Byte Size Bottleneck
A standard Master Boot Record must be exactly 512 bytes, terminating with the `0xAA55` magic signature. Adding step-by-step visual text strings and introducing complex delay loops quickly swelled the compiled binary past the strict 510-byte code threshold. This caused compiler assembly errors (`TIMES value is negative`).
* **Resolution**: Performed aggressive space optimization ("code golfing") of assembly instructions, streamlined print functions to share parameters, and compressed static string lengths to reclaim bytes, safely staying within the 512-byte hardware boundary.

#### B. Emulator Incompatibilities with Delay Functions
Initially, a microsecond delay was implemented using BIOS `INT 15h, AH=86h`. While this worked well in standard virtualization platforms like QEMU, it caused complete, silent system hangs in Emu8086, as Emu8086 is a simplified educational interpreter that lacks a complete BIOS interrupt table implementation.
* **Resolution**: Developed a robust, highly compatible custom delay function using the BIOS tick counter (`INT 1Ah, AH=00h`). Since the system clock increments at ~18.2 Hz (18.2 ticks per second) across all x86 platforms and emulators, we polling-checked for a delta of 18 ticks, yielding a stable 1-second delay that executes flawlessly in both QEMU and Emu8086.

#### C. Relocation Addressing & Segments Synchronization
Performing self-relocation changes the Code Segment (`CS`) dynamically. In early iterations, transitioning `CS` to the new segment via a far jump without immediately resetting data segments (`DS`, `ES`, `SS`) caused variables to be read from old addresses or corrupt stack frames.
* **Resolution**: Synchronized the segment registers immediately after the far jump (`mov ax, cs`, `mov ds, ax`, `mov es, ax`) and re-built a dedicated stack in high memory with a Safe Stack Pointer (`mov sp, 0xFFFF`), ensuring complete isolation of the running bootloader.

