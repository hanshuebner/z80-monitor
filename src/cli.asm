
; parse_line - parses the command line, counting the number of arguments (space separated) 
; and stores poiters to them in the array pointed to by BC (argc(count)/argv(pointers to all arguments)). 
; HL is a pointer to the string
; affects: none
parse_line:     
                push    hl                      ; save hl
                push    bc                      ; save original bc

                inc     bc                      ; BC now points to argv array

                ld      a, 0
                push    af                      ; counter on stack

                call    str_next_token          ; read command name
parse_line_loop:
                cp      EOS                     ; last character was EOS?
                jr      Z, parse_line_ret   ; YES - exit

                ; increment count
                pop     af
                inc     a
                push    af

                ; store pointer to next token (contained in DE now because of str_next_token)
                ld      a, e
                ld      (bc), a                 ; store E first (little endian)
                inc     bc

                ld      a, d                
                ld      (bc), a                 ; store D
                inc     bc      

                ; move DE into HL (for str_next_token)
                ld      h, d
                ld      l, e
                
                call    str_next_token          ; check next token
                
                jr      parse_line_loop

parse_line_ret:
                pop     af
                pop     bc                      ; restore bc to point to argc
                ld      (bc), a                 ; store count in argc

                pop     hl                      ; restore hl
                ret



; excecute_command - processes a command from the strig given in HL, IX should point to start of the command table and B contain the number of commands
; affects: AF, HL, DE, B
; arguments: HL - pointer to string with command name
; returns: none
excecute_command:
                ld      e, (ix+0)                 ; load the address to the command string
                ld      d, (ix+1)

                
                call    str_cmp                 ; compare the current command string with the entered command
                jr      C, excecute_command_found   ; there is a match!

                ld      de, 4                   ; do IX += 4
                add     IX, de

                djnz    excecute_command        ; go through all entries, if we fall through here, no command was found :/

                push    hl                      ; print command not found message
                ld      hl, str_unrec_cmd
                call    print_string
                pop     hl
                call    print_string
                
                ret                             ; return

excecute_command_found:
                ld      l, (IX+2)               ; load address of command to excecute
                ld      h, (IX+3)
                jp      (hl)                    ; continue excecution at command
                

str_unrec_cmd:  db     "Unrecognized command: ", EOS

