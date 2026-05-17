; ============================================================================
; BIOS Bootkit — Single-file build
; Assemble with: nasm -f bin bootkit.asm -o disk.img
; Run with:      qemu-system-i386 -drive format=raw,file=disk.img,if=floppy
; ============================================================================

[bits 16]

; ============================================================================
; STAGE 1 — Master Boot Record
; ============================================================================
[org 0x7C00]

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov [boot_drive], dl
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov ax, 0x0003
    int 0x10
    call clear_screen

    mov si, splash_msg
    mov bl, 0x0B
    call print_string_at_center

    mov si, step1_msg
    mov bl, 0x07
    mov dh, 10
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

    ; Load Stage 2 from sector 2 into 0x0000:0x8000
    xor ax, ax
    mov es, ax
    mov bx, 0x8000

    mov ah, 0x02
    mov al, 1
    mov ch, 0
    mov cl, 2
    mov dh, 0
    mov dl, [boot_drive]
    int 0x13
    jc .disk_error

    mov si, step4_msg
    mov bl, 0x0A
    mov dh, 16
    call print_string
    call sleep

    mov si, final_msg
    mov bl, 0x0E
    mov dh, 18
    call print_string
    call sleep

    jmp 0x0000:0x8000

.disk_error:
    mov si, disk_err_msg
    mov bl, 0x0C
    mov dh, 22
    call print_string
    jmp $


clear_screen:
    pusha
    mov ax, 0x0600
    mov bh, 0x07
    mov cx, 0x0000
    mov dx, 0x184F
    int 0x10
    popa
    ret

print_string:
    mov dl, 10
.loop:
    lodsb
    or al, al
    jz .end
    push si
    mov ah, 0x02
    mov bh, 0
    int 0x10
    mov ah, 0x09
    mov cx, 1
    int 0x10
    inc dl
    pop si
    jmp .loop
.end:
    ret

print_string_at_center:
    mov dh, 5
    mov dl, 30
.loop:
    lodsb
    or al, al
    jz .end
    push si
    mov ah, 0x02
    mov bh, 0
    int 0x10
    mov ah, 0x09
    mov cx, 1
    int 0x10
    pop si
    inc dl
    jmp .loop
.end:
    ret

sleep:
    pusha
    mov ah, 0x86
    mov cx, 0x000F
    mov dx, 0x4240
    int 0x15
    popa
    ret


splash_msg   db "BIOS Bootkit", 0
step1_msg    db "Step 1: Relocation to high memory successful.", 0
step2_msg    db "Step 2: Stack and segments initialized.", 0
step3_msg    db "Step 3: Loading Stage 2 payload from disk...", 0
step4_msg    db "Step 4: Payload loaded successfully.", 0
final_msg    db "Handing control to Stage 2...", 0
disk_err_msg db "DISK READ ERROR! Bootkit failed.", 0
boot_drive   db 0

times 510-($-$$) db 0
dw 0xAA55


; ============================================================================
; STAGE 2 — Payload (lives in sector 2, loaded to 0x8000 at runtime)
; ============================================================================
[org 0x8000]

payload_start:
    cli
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov ax, 0x0003
    int 0x10
    call p_clear_screen

    mov si, banner_msg
    mov bl, 0x0C
    mov dh, 2
    call p_print_string

    mov si, warn_msg
    mov bl, 0x07
    mov dh, 4
    call p_print_string

    mov si, prompt_msg
    mov bl, 0x0F
    mov dh, 6
    call p_print_string

    mov ah, 0x02
    mov bh, 0
    mov dh, 6
    mov dl, 30
    int 0x10

    mov cx, 32
.pwd_loop:
    mov ah, 0x00
    int 0x16

    cmp al, 0x0D
    je .pwd_done
    cmp al, 0x08
    je .pwd_loop

    push cx
    mov ah, 0x0E
    mov al, '*'
    int 0x10
    pop cx
    loop .pwd_loop
.pwd_done:

    mov si, accepted_msg
    mov bl, 0x0A
    mov dh, 8
    call p_print_string

    call p_sleep
    call p_sleep

    mov si, klog_header
    mov bl, 0x0E
    mov dh, 11
    call p_print_string

    mov si, klog_hint
    mov bl, 0x07
    mov dh, 12
    call p_print_string

    mov ah, 0x02
    mov bh, 0
    mov dh, 14
    mov dl, 5
    int 0x10

    mov cx, 20
.klog_loop:
    push cx
    mov ah, 0x00
    int 0x16
    cmp al, 0x0D
    je .skip_echo
    mov ah, 0x0E
    int 0x10
.skip_echo:
    pop cx
    loop .klog_loop

    mov si, backdoor_msg
    mov bl, 0x0C
    mov dh, 18
    call p_print_string

    mov si, ip_msg
    mov bl, 0x07
    mov dh, 19
    call p_print_string

    mov si, port_msg
    mov bl, 0x07
    mov dh, 20
    call p_print_string

    mov si, done_msg
    mov bl, 0x0B
    mov dh, 22
    call p_print_string

.hang:
    hlt
    jmp .hang


p_clear_screen:
    pusha
    mov ax, 0x0600
    mov bh, 0x07
    mov cx, 0x0000
    mov dx, 0x184F
    int 0x10
    popa
    ret

p_print_string:
    mov dl, 5
.loop:
    lodsb
    or al, al
    jz .end
    push si
    mov ah, 0x02
    mov bh, 0
    int 0x10
    mov ah, 0x09
    mov cx, 1
    int 0x10
    inc dl
    pop si
    jmp .loop
.end:
    ret

p_sleep:
    pusha
    mov ah, 0x86
    mov cx, 0x000F
    mov dx, 0x4240
    int 0x15
    popa
    ret


banner_msg     db "== SYSTEM SECURITY CHECK ==", 0
warn_msg       db "Unauthorized access attempt detected.", 0
prompt_msg     db "Administrator password:", 0
accepted_msg   db "Credentials accepted. Elevating to ring 0...", 0

klog_header    db "Diagnostic keyboard test active.", 0
klog_hint      db "Please type 20 characters for verification:", 0

backdoor_msg   db "Backdoor channel established.", 0
ip_msg         db "  remote host : 10.0.0.1", 0
port_msg       db "  listen port : 4444", 0
done_msg       db "Payload finished. CPU halted.", 0

times 1024-($-$$) db 0