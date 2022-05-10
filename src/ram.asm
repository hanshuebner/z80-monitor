;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;           VARIABLES            ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	org     $8000

boot_flag:      db     0                ; boot flag

argc:           ds      1               ; holds number of arguments
argv:           ds      16*2            ; array of pointers to the respective arguments (16 arguments = 32 bytes in size, see below)
str_buffer:     ds      128             ; a string buffer

; temporary stack storage space

mon_reg_stack:      ds  20              ; register stack for storing the register contents while in the monitor (BREAKPOINT)
                                        ; 20 bytes: A F B C D E H L + A' F' B' C' D' E' H' L' + IX IY

mon_reg_rtn_addr:   ds  2               ; stores the return address (just for displaying purposes)
mon_stack_backup:   ds  2               ; just a backup variable to not mess up the original stack pointer while saving/restoring

cf_sector_buffer:   ds  512
END_OF_PROGRAM:  equ    ($ + 0FFH) & 0FF00H   ; next 256 byte boundary
