; port definitions for the SIO/2 chip
SIO_BASE:   equ    $80
SIO_A_DATA: equ    SIO_BASE + 0
SIO_A_CTRL: equ    SIO_BASE + 1
SIO_B_DATA: equ    SIO_BASE + 2
SIO_B_CTRL: equ    SIO_BASE + 3

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;        
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Serial I/O-routines  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; sio_init: initializes the SIO/2 for serial communication
; affects: HL, B, C
sio_init:       LD      B, 12                   ; load B with number of bytes (12)
                LD      HL, sio_init_data       ; HL points to start of data
                LD      C, SIO_A_CTRL           ; I/O-port for write
                OTIR                            ; block write of B bytes to [C] starting from HL
                ret

sio_init_data:  db     $00, %00110000          ; write to WR0: error reset
                db     $00, %00011000          ; write to WR0: channel reset
                db     $01, %00000000          ; write to WR1: no interrupts enabled
                db     $03, %11000001          ; write to WR3: enable RX 8bit
                db     $04, %00000100          ; write to WR4: clkx1,1 stop bit, no parity
                db     $05, %01101000          ; write to WR5: DTR inactive, enable TX 8bit, BREAK off, TX on, RTS inactive


; tx_ready: waits for transmitt buffer to become empty
; affects: none
sio_tx_ready:   push    af
sio_tx_ready_loop:
                in      a, (SIO_A_CTRL)         ; read RR0
                bit     2, a                    ; check if bit 2 is set
                jr      z, sio_tx_ready_loop            ; if no - check again
                pop     af
                ret
                
; rx_ready: waits for a character to become available
; affects: none
sio_rx_ready:   push    af
sio_rx_ready_loop:  
                in      a, (SIO_A_CTRL)         ; read RR0
                bit     0, a                    ; check if bit 0 is set
                jr      z, sio_rx_ready_loop        ; if no - rx buffer has no data => check again
                pop     af
                ret
                
        
; sends byte in reg A   
; affects: none
putc:           call    sio_tx_ready
                out     (SIO_A_DATA), a         ; write charactet
                ret                             ; return

; getc: waits for a byte to be available and reads it
; returns: A - read byte
getc:           call    sio_rx_ready
                in      a, (SIO_A_DATA)
                ret

;// TODO: Move the rest below to another file, not really part of the serial i/o driver!

; print_newline: prints a CR/LF pair to advance to the next line 
; affects: none
print_newline:  push    af                      ; save registers

                ld      a, CR                   ; print Carriage Return
                call    putc
                ld      a, LF                   ; print Line Feed
                call    putc
                
                pop     af                      ; restore registers
                ret
                
; print_string: prints a string which starts at adress HL and is terminated by EOS-character
; affects: none
print_string:   push    af
                push    hl
                
print_string_1: LD      A,(HL)                  ; load next character
                CP      0                       ; is it en End Of String - character?
                jr      Z, print_string_2       ; yes - return
                call    putc                    ; no - print character
                INC     HL                      ; HL++
                jr      print_string_1          ; do it again
                
print_string_2: pop     hl
                pop     af
                ret


; get_nibble: gets a nibble from a correctly entered hexadecimal digit (blocks until one is recieved) 
; returns: A - nibble entered
get_nibble:
                call    getc                    ; get a character
                call    to_upper                ; convert to upper case
                call    is_hex                  ; is character a hexadecimal?
                jr      nc, get_nibble          ; no, get another one
                call    nibble2val              ; convert hexadecimal
                call    print_nibble            ; echo character
                ret
                
; get_byte: gets a byte from the serial port in two hexadecimal numbers, blocks since it calls get_nibble
; returns: A - byte entered
get_byte:       push bc
                rlc     a
                
                call    get_nibble
                rlc     a
                rlc     a
                rlc     a
                ld      b, a
                call    get_nibble
                or      b
                
                pop bc
                ret
; get_word: gets a word from 4 hexadecimal digits
; affects: none
get_word:       push    af                      ; save registers
                call    get_byte                ; get one byte and put in h
                ld      h,a
                call    get_byte                ; get one byte and put in l
                ld      l, a
                pop     af                      ; restore registers and return
                ret

        
; print_nibble: prints a single hex nibble which is given in the lower 4 bits of A
print_nibble:   push    af                      ; dont destroy the contents of a
                and     $0f                     ; just in case...
                add     a, '0'                  ; if we have a digit we are done here
                cp      '9' + 1                 ; is the result > 9 ?
                jr      c, print_nibble_1       
                add     a, 'A' - '0' - $0a      ; Take care of A-F
print_nibble_1: 
                call    putc                ; print nibble and return
                pop     af                      ; restore contents of a
                ret
                
; print_byte: prints a single byte in A as two hexadecimal charcters
; affects: none
print_byte:     push    af                      ; save registers
                push    bc
                ld      b, a                    ; copy byte to b register
                rrca                            ; shift down the high nibble in A
                rrca
                rrca
                rrca
                call    print_nibble            ; print high nibble
                ld      a, b                    ; move low nibble to a
                call    print_nibble            ; print low nibble
                
                pop     bc                      ; restore registers
                pop     af
                ret
                
; print_word: prints a word contained in HL as 4 hexadecimal characters
; affects: none
print_word:     push    hl                      ; save registers
                push    af
                
                ld      a, h                    ; print high byte
                call    print_byte
                ld      a, l                    ; print low byte
                call    print_byte
                
                pop     af                      ; restore registers
                pop     hl
                ret

                ;.EXPORT    getc, get_byte, get_byte, get_word, putc, print_byte, print_word, print_string
