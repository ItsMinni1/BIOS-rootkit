; -----------------------------------------------------------------------------
; STAGE 2 PAYLOAD
; This is loaded by the MBR at 0x8000.
; -----------------------------------------------------------------------------

[bits 16]
[org 0x8000]

payload_start:
    ; The segments should already be set by Stage 1, but let's be sure.
    xor ax, ax
    mov ds, ax
    mov es, ax

    ; 1. Display Intrusion Success Message
    mov si, intrusion_msg
    mov bl, 0x0A    ; Light Green
    mov dh, 18      ; Row 18
    call print_string_at_center_payload

    mov si, status_msg_final
    mov bl, 0x0E    ; Yellow
    mov dh, 20      ; Row 20
    call print_string_at_center_payload

.loop:
    hlt
    jmp .loop

; -----------------------------------------------------------------------------
; HELPER FUNCTIONS (Copied/Adapted for standalone execution)
; -----------------------------------------------------------------------------

print_string_at_center_payload:
    mov dl, 25      ; Column 25
.loop_p:
    lodsb
    or al, al
    jz .end_p
    push si
    mov ah, 0x02    ; Set cursor
    mov bh, 0
    int 0x10
    
    mov ah, 0x09    ; Write char
    mov cx, 1
    int 0x10
    
    inc dl
    pop si
    jmp .loop_p
.end_p:
    ret


intrusion_msg       db "SUCCESS! BOOTKIT DEPLOYED", 0
status_msg_final    db "Payload active.", 0
