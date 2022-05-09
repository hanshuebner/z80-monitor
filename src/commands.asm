; TABLE OF COMMANDS, holds pointer to string, and address
str_cmd_dump:       dm "dump\0"
str_cmd_rst:        dm "rst\0"
str_cmd_test:       dm "test\0"
str_cmd_help:       dm "help\0"
str_cmd_breaktest:  dm "break\0"
str_cmd_continue:   dm "cont\0"
str_cmd_reg:        dm "reg\0"
str_cmd_cf_init:    dm "cfinit\0"
str_cmd_cf_id:      dm "cfid\0"
str_cmd_cf_read:    dm "cfread\0"

command_table:  dw     str_cmd_help, cmd_help
                dw     str_cmd_dump, cmd_dump  ; dump command
                dw     str_cmd_rst, cmd_reset  ; reset command
                dw     str_cmd_continue, cmd_continue
                dw     str_cmd_test, cmd_test  ; test command
                dw     str_cmd_breaktest, cmd_breaktest ; breaktest command
                dw     str_cmd_reg, dump_registers ; dump registers command
                dw     str_cmd_cf_init, cf_init
                dw     str_cmd_cf_id, cmd_cf_id
                dw     str_cmd_cf_read, cmd_cf_read
command_table_entries:  equ    ($ - command_table) / (2*2) ; calculate size using bytes


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_help - prints the help info for the user              
cmd_help:       ld      hl, str_commands
                call    print_string
                ret



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_dump - parses command line for a start and end address and then calls the dump_memory function to dump the data
cmd_dump:       ld      a, (argc)               ; load number of arguments
                cp      2
                jr      nz, cmd_dump_err        ; if there are not 2 arguments, print error message

                ld      hl, (argv)              ; first argument
                call    str_parse_word
                jr      nc, cmd_dump_err
                push    de

                ld      hl, (argv + 2)          ; second argumend
                call    str_parse_word
                jr      nc, cmd_dump_err
;// TODO: fix uneeven push/pop caused by invalid arguments              
                pop     hl
                call    dump_memory
                ret

cmd_dump_err:   ld      hl, str_cmd_dump_err
                call    print_string
                ret

str_cmd_dump_err: dm "Usage: dump <START> <END>", CR, LF, EOS

; dump_memory: prints a nice table of the memory contents starting at address HL and ending at address DE (rounded up to closest multiple of 16)
; affects: none
dump_memory:
                push    hl                      ; save registers
                push    de
                push    af
                
                ld      a, l                    ; align start address in HL to 16 byte chunks (rounds down)
                and     $f0
                ld      l, a
                
                inc     de                      ; to include DE if it happens to be a multiple of 16 (prints one extra line in that case)
                
                push    hl                      ; save start address
                ld      hl, dump_memory_header  ; print header
                call    print_string

                pop     hl                      ; restore start address
                
row_loop:       call    print_word              ; print the starting address
                ld      a, SPACE
                
                call    putc                    ; print space
                call    putc
                
                push    hl                      ; store the value of HL
                ld      b, 16                   ; load 16 into b register 
byte_loop:      ld      a, (HL)                 ; load byte at (HL)
                call    print_byte              ; print it
                
                ld      a, SPACE                ; print a space
                call    putc
                
                inc     HL                      ; HL now points to the next byte in memory
                
                djnz    byte_loop               ; do this B times (16)
                
                
                ld      a, '|'                  ; print a '|'
                call    putc
                
                ld      b, 16                   ; load 16 into b register   
                
                pop     hl                      ; restore the value of HL
ascii_loop:     ld      a, (HL)                 ; load byte at (HL)
                cp      SPACE                   ; is this a valid (>= 20 <=> no control character) character? 
                jr      nc, ascii_loop_1        ; yes
                ld      a, '.'                  ; no - print '.' instead
ascii_loop_1:   call    putc                    ; print character
                
                inc     HL                      ; HL now points to the next byte in memory
                djnz    ascii_loop              ; do this B times (16)
                
                ld      a, '|'                  ; print a '|'
                call    putc
                
                call    print_newline
                
                ; check to do this until de >= hl
                push    hl                      ; save hl
                and     a                       ; reset carry flag
                sbc     hl, de                  ; do HL - DE, carry inticates DE > HL
                pop     hl                      ; restore hl since the above modifies it
                jr      c, row_loop             ; if DE > HL, do next row
                
                pop     af                      ; restore registers
                pop     de
                pop     hl
                ret
                
                
dump_memory_header: dm "      00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F\r\n\r\n\0"
                
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_reset - does a cold or warm reset
cmd_reset:      push    af
                push    hl
                
                ld      hl, cmd_reset_str
                call    print_string
                
                call    getc
                call    to_upper

                call    print_newline
                rst     30H
                cp      'Y'                     ; cold reset?
                jr      nz, cmd_reset_1         ; no - skip to reset
                ld      hl, boot_flag           ; reset warm boot flag (force cold boot)
                ld      (hl), 0     
                
cmd_reset_1:    rst     00              
                
                pop     hl
                pop     af
                ret
cmd_reset_str: dm "Reset: Cold reset? (Y/N): \0"


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
; cmd_jump - jumps to specific address and continues excecution from there
cmd_jump:       ; make sure there are exactly 1 argument
                ld      a, (argc)
                cp      1               
                jr      nz, cmd_jump_error
                
                ; read in argument
                ld      hl, (argv)
                call    str_parse_word
                jr      nc, cmd_jump_error
                
                push    de                      ; store address on stack...
                ret                             ; ...wich makes this call the specified function

cmd_jump_error:
                ld      hl,(str_cmd_jump_err)
                call    print_string

                ret


str_cmd_jump_err: dm "Usage: jump <ADDR>", CR, LF, EOS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_continue - exits out of monitor mode and continues on
cmd_continue:   pop     hl      ; exit out of excecute_command
                jp      monitor_leave   

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
; cmd_breatest - tests the "break" functionality by issuing rst 30H eight times
cmd_breaktest:
                ld      b, 8
                ld      a,0
cmd_breaktest_loop:
                inc     a


                rst     30H             ; breakpoint!
                djnz    cmd_breaktest_loop
                ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; cmd_cf_id - loads and dumps the ID sector of the CF card
cmd_cf_id:      ld      HL, cf_sector_buffer    ; pointer to cf sector buffer in RAM
                call    cf_read_id

                ret     C

                ld      HL, cf_sector_buffer    ; pointer to cf sector buffer in RAM
                ld      DE, cf_sector_buffer + 512 ; end of cf sector buffer in RAM
                call    dump_memory
                ret


cmd_cf_read:    ld      HL, cf_sector_buffer    ; pointer to cf sector buffer in RAM
                call    cf_read_id


                ld      HL, cf_sector_buffer    ; pointer to cf sector buffer in RAM
                ld      DE, cf_sector_buffer + 512 ; end of cf sector buffer in RAM
                call    dump_memory
                ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; DOES NOT WORK ANYMORE:::::...-.-.!:!!:!:
cmd_test:       call    print_string
                
                call    str_parse_word              
                JR      C, cmd_test_1

                ld      a, $ff
                ret
                
cmd_test_1:     out     (LED_PORT), a
                push    de
                pop     hl
                call    print_word
                ret




 
