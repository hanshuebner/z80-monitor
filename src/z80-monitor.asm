; inspiration (with many others): https://github.com/lmaurits/lm512
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;           CONSTANTS            ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LED_PORT:     equ   $00


BOTTOM_OF_STACK: equ $ffff          ; "top" stack adress at 4 KB

BOOT_FLAG_WARM:  equ    $AA

              include "constants.asm"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;             CODE               ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Excecution starts here
                org $0000
                DI                                  ; disable interrupts
                jr      initialize                  ; skip reset vector(s)
                
;;;;;;;;;; AREA FOR RESET VECTORS AND SO ON HERE ;;;;;;;;;;;;
                org    $0030
rst30:          jp      monitor_enter               ; breakpoint reset vector
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

initialize:     ld      sp, BOTTOM_OF_STACK         ; set up stack pointer 
                
                call    sio_init                    ; initialize serial communication
                
                ld      HL, str_init                ; print welcome message
                call    print_string
                
                ; cold/warm start
                ld      hl, boot_flag
                ld      a, (hl)                     ; load boot_flag contents into A register
                cp      BOOT_FLAG_WARM
                ld      hl, str_warm_boot
                call    z, print_string             ; if this is warm boot, print string
                jp      z, main_command_loop        ; if this is warm boot, skip to main
                
                
                ld      hl, str_cold_boot           ; print cold boot message
                call    print_string
                
                ; clear RAM
                ld      hl, END_OF_PROGRAM          ; load hl with starting point of area to be cleared
                ld      de, END_OF_PROGRAM + 1      ; load de with starting point of area to be cleared + 1
                ld      bc, $7fff - END_OF_PROGRAM  ; bc holds number of bytes to clear (NO parantesis since this is another command!!)
                ld      (hl), $00                   ; load the first byte with 0
                ldir                                ;d do (DE)<-(HL); HL++, DE++, until BC == 0. Since HL is one byte behind DE, zeroes will be copied one byte forward untill all of memory is cleared
                
                ld      hl, boot_flag               ; set the boot flag
                ld      (hl), BOOT_FLAG_WARM

                jr      main_command_loop           ; enter main command line   


; monitor program starts here
; monitor_enter - saves all the registers to a special area in ram
monitor_enter:  ld      (mon_stack_backup), SP  ; backup stack pointer

                ; Save all registers
                ld      SP, mon_reg_stack + 1;

                push    af
                push    bc
                push    de
                push    hl
                ex      af,af'                  ; swap registers
                exx 

                push    af
                push    bc
                push    de
                push    hl
                ex      af,af'                  ; swap registers again
                exx 

                push    ix                      ; save ix and iy
                push    iy

                
                
                ld      SP, (mon_stack_backup)  ; restore original stack pointer

                pop     hl                      ; pop return address to hl
                push    hl                      ; push return address again

                ld      (mon_reg_rtn_addr), hl  ; save return address in variable

                ; DO REAL STUFF HERE!!! WE ARE IN A SAFE ENVIRONMENT
                
                call    dump_registers

                ld      hl, str_mon_cont
                call    print_string
                call    getc                    ; wait for a character
                call    to_upper
                cp      'M'
                jr      NZ, monitor_leave

main_command_loop:          

                call    print_newline
                ld      a, '>'                  ; print command prompt
                call    putc

                ld      hl, str_buffer          ; hl points to start of string buffer
                call    read_line               ; read input line

                ld      a, (hl)                 ; if command line is empty, just skip
                cp      EOS
                jr      Z, main_command_loop

                call    print_newline       
                
                ld      bc, argc                ; load pointer to argc/argv array
                call    parse_line              ; parse entered command line string

                ld      ix, command_table       ; pointer to command table  
                ld      b, command_table_entries    ; load b with number of entries to test (this is precalculated in the assembler)
                call    excecute_command        ; excecute the command

                jr      main_command_loop       ; do it again


                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; monitor_leave - restores all registers and returns to original caller, effectively leaves "monitor" mode
monitor_leave:
                ld      (mon_stack_backup), SP  ; backup stack pointer

                ; Restore all registers
                ld      SP, mon_reg_stack - (20-1); set stack pointer to start at the bottom of our saved registers stack

                pop     iy                      ; restore iy and ix
                pop     ix

                ex      af,af'                  ; swap registers
                exx 
                pop     hl
                pop     de
                pop     bc
                pop     af

                ex      af,af'                  ; swap registers again
                exx 
                pop     hl
                pop     de
                pop     bc
                pop     af                          
                
                ld      SP, (mon_stack_backup)  ; restore stack pointer
                ret                             ; return!

str_mon_cont:   db     "Press m to re-enter monitor, or any other key to continue excecution.", CR, LF, EOS

; dump_registers - prints the contents of the stored register stack in a nice format
dump_registers: 
                ld      hl, str_regdump_pc      ; print pc string
                call    print_string
                ld      hl, (mon_reg_rtn_addr)  ; print return address
                dec     hl                      ; will now point at the rst instruction
                call    print_word
                call    print_newline
                call    print_newline

                ld      de, mon_reg_stack       ; pointer to saved registers

                ld      hl, str_regdump         ; print header for normal registers
                call    print_string
                ld      b, 8                    ; dump 8 registers
                call    dump_registers_loop
                call    print_newline
                call    print_newline

                ld      hl, str_regdump_alt     ; print header for alterative registers
                call    print_string
                ld      b, 8                    ; dump 8 registers
                call    dump_registers_loop
                call    print_newline
                call    print_newline

                ld      hl, str_regdump_index   ; print header for index registers
                call    print_string
                ld      b, 4                    ; dump 4 registers
                call    dump_registers_loop
                call    print_newline
                call    print_newline

                ret                             ; return

dump_registers_loop:
                ld      a, (de)                 ; load byte for next register
                dec     de                      ; move to next
                call    print_byte              ; print byte
                ld      a, SPACE
                call    putc
                djnz    dump_registers_loop

                ret

str_regdump_pc:     db     "BREAK @ 0x", EOS ;
str_regdump:        db     "A  F  B  C  D  E  H  L", CR, LF, EOS
str_regdump_alt:    db     "A' F' B' C' D' E' H' L'", CR, LF, EOS
str_regdump_index:  db     "IX    IY", CR, LF, EOS


              include "cli.asm"
              include "commands.asm"
              include "string.asm"
              include "sio_driver.asm"
              include "cf_driver.asm"
                
                
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; wait function  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  waits using a loop
;;  affects b
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; pause:
;       ;PUSH   AF
;       PUSH    BC
;       LD      B, $ff
; pause_loop:
;       DJNZ    pause_loop
        
;       POP     BC
;       ;POP        AF
;       RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                        DATA                                                                              ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
str_warm_boot:  db     "Warm Boot...", CR, LF, EOS
str_cold_boot:  db     "Cold Boot...", CR, LF, EOS
str_init:       DB     " Z80 Monitor v0.2 (C) 2017 Anton Berneving\r\n\r\n\0"
str_commands: DB    " Available Commands are: \r\n"
              DB    "    help - show this list\r\n"
              DB    "    rst - Reset Cold/Warm\r\n"

              DB    "    dump - print memory contents\r\n"
              DB    "    *fill - fill bytes in memory\r\n"
              DB    "    *move - copy data in memory\r\n"
              DB    "    *load - load data to address\r\n"
                
              DB    "    reg - view register contents @ BREAK\r\n"
                
              DB    "    jump - jump to address\r\n"
              DB    "    cont - continue excecution\r\n"
              db 0

;// TODO: MOVE THIS TO ITS OWN "RAM"-FILE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;           VARIABLES            ;;
;;  BLOCK n, reserves n bytes and ;;
;;  the label gets the value of   ;;
;;  the first address             ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

boot_flag:      DB     0                       ; boot flag

argc:         ds 1              ; holds number of arguments
argv:         ds 16*2           ; array of pointers to the respective arguments (16 arguments = 32 bytes in size, see below)
str_buffer:     ds  128                     ; a string buffer

; temporary stack storage space

mon_reg_stack:      org    $+20                ; register stack for storing the register contents while in the monitor (BREAKPOINT)
                                                ; 20 bytes: A F B C D E H L + A' F' B' C' D' E' H' L' + IX IY

                    org    $+1                 ; PADDING: needed to advance the instruction pointer  to the next byte when using .BLOCK below

mon_reg_rtn_addr:   DS  2                   ; stores the return address (just for displaying purposes)
mon_stack_backup:   DS  2                   ; just a backup variable to not mess up the original stack pointer while saving/restoring

cf_sector_buffer:   DS  512                 ; a temporary location to load a sector from the CF card into

END_OF_PROGRAM:  equ    ($ + 0FFH) & 0FF00H   ; next 256 byte boundary

; .ECHO "END_OF_PROGRAM: "
; .ECHO END_OF_PROGRAM
; .ECHO "\n"

              END
