#make_bin#

; -----------------------------------------------------------------------------
; ANTIGRAVITY BOOTKIT DEMONSTRATION (Emu8086 Compatible)
; Educational MBR-based bootloader for Computer Organization course.
; -----------------------------------------------------------------------------

; We will use ORG 0000h because BIOS loads us at 0000:7C00h but we can treat it as 07C0h:0000h
ORG 0000h

start:
    ; BIOS loads us at 0000:7C00h (or 07C0:0000h).
    ; We manually set DS and ES to 07C0h so ORG 0000h works correctly.
    cli
    mov ax, 07C0h
    mov ds, ax
    mov es, ax
    ; 1. Initial Setup
    cli             ; Clear interrupts
    mov boot_drive, dl ; Save boot drive index

    ; --- RESEARCH IMPLEMENTATION: start_mover (Relocation) ---
    ; We relocate the MBR to 07E0h:0000h to demonstrate a closeby address.
    mov ax, 07C0h  ; Current location segment
    mov ds, ax
    xor si, si      ; Source offset 0
    
    mov ax, 07E0h  ; Destination segment
    mov es, ax
    xor di, di      ; Destination offset 0
    
    mov cx, 256     ; 512 bytes (256 words)
    rep movsw
    
    ; Jump to the new location
    jmp 07E0h:relocated

relocated:
    ; 2. Adjust Segments for High Memory
    mov ax, cs      ; AX = 07E0h
    mov ds, ax
    mov es, ax
    mov ss, ax      ; Use high memory for stack too
    mov sp, 0FFFFh  ; Stack at top of segment
    sti             ; Re-enable interrupts

    ; 2. Visual Excellence: Clear Screen & Set Video Mode
    mov ax, 0003h  ; Set 80x25 Color Text Mode
    int 10h

    ; Draw Header
    call clear_screen
    mov si, offset splash_msg
    mov bl, 0Bh    ; Light Cyan color
    call print_string_at_center

    mov si, offset step1_msg
    mov bl, 07h    ; White color
    mov dh, 10      ; Row 10
    call print_string
    call sleep

    mov si, offset step2_msg
    mov bl, 07h
    mov dh, 12
    call print_string
    call sleep

    mov si, offset final_msg
    mov bl, 0Eh    ; Yellow
    mov dh, 14
    call print_string
    call sleep

hang:
    jmp hang           ; Hang



; -----------------------------------------------------------------------------
; HELPER FUNCTIONS
; -----------------------------------------------------------------------------

clear_screen:
    mov ax, 0600h  ; Scroll up window (0 = clear)
    mov bh, 07h    ; Light gray on black
    mov cx, 0000h  ; Top-left (0,0)
    mov dx, 184Fh  ; Bottom-right (24,79)
    int 10h
    ret

; SI = String, BL = Attribute, DH = Row
print_string:
    mov dl, 10      ; Default column
print_loop:
    lodsb
    or al, al
    jz print_end
    push si
    mov ah, 02h    ; Set cursor position
    mov bh, 0       ; Page 0
    int 10h
    
    mov ah, 09h    ; Write character/attribute
    mov cx, 1       ; One character
    int 10h
    
    inc dl          ; Next column
    pop si
    jmp print_loop
print_end:
    ret

; SI = String, BL = Attribute
print_string_at_center:
    mov dh, 5       ; Fixed row for splash
    mov dl, 30      ; Roughly center
    jmp print_string

sleep:
    push ax
    push cx
    push dx
    push bx

    ; Get current tick count from BIOS
    mov ah, 00h
    int 1Ah        ; CX:DX = ticks since midnight
    mov bx, dx     ; Save low word of start tick

.wait_loop:
    mov ah, 00h
    int 1Ah        ; CX:DX = current ticks
    mov ax, dx
    sub ax, bx     ; Calculate difference (current - start)
    cmp ax, 18     ; 18 ticks is roughly 1 second (18.2 Hz)
    jb .wait_loop  ; If less than 18 ticks, keep waiting

    pop bx
    pop dx
    pop cx
    pop ax
    ret

; -----------------------------------------------------------------------------
; DATA SECTOR
; -----------------------------------------------------------------------------

splash_msg      db "BIOS Bootkit", 0
step1_msg       db "[*] Relocated to 07E0h", 0
step2_msg       db "[*] Segments init", 0
final_msg       db "control take hehe >:) ", 0

boot_drive       db 0

; -----------------------------------------------------------------------------
; BOOT SIGNATURE & PADDING
; -----------------------------------------------------------------------------
ORG 510
dw 0AA55h


