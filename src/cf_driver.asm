; Register and programming information from the following sources
;   Mostly register definitions:    http://blog.retroleum.co.uk/electronics-articles/an-8-bit-ide-interface/ 
;   Initialization code:            http://www.smbaker.com/z80-retrocomputing-10-rc2014-compactflash-board
; 
; Register  Usage:
;   $0      IDE Data Port
;   $1      Read: Error Code
;   $2      Number Of Sectors To Transfer
;   $3      Sector address LBA 0 (0:7)
;   $4      Sector address LBA 1 (8:15)
;   $5      Sector address LBA 2 (16:23)
;   $6      Sector address LBA 3 (24:27)
;   $7      Read: Status, Write: Issue Command To Drive
;

; ** Register $1 Error Bits **
;  Bit  Condition
;   0    1 = DAM not found
;   1    1 = Track 000 not found
;   2    1 = Command aborted
;   3        Reserved
;   4    1 = ID not found
;   5        Reserved
;   6    1 = Uncorrectable ECC error
;   7    1 = Bad block detected


; ** Register $6 (LBA 3) Details **
;   Bit 0:3 = LBA bits (24:27)
;   Bit 4   = Select Master (0) or Slave (1) drive
;   Bit 5   = Always set to 1
;   Bit 6   = Always Set to 1 for LBA Mode Access
;   Bit 7   = Always set to 1

; ** Register $7 STATUS Bits **
;  Bit Name   Condition
;   0   ERR    1 = Previous command ended in an error (see register $1 for more info)
;   1   IDX        (not important)
;   2   CORR       (not important)
;   3   DRQ    1 = Data Request Ready (Sector buffer ready for transfer)
;   4   DSC        (not important)
;   5   DF     1 = Write Fault
;   6   RDY    1 = Ready for command
;   7   BUSY   1 = Controller is busy executing a command.



; Register port definitions for the CF-card interface
CF_BASE:    equ        $40

CF_DATA:    equ        CF_BASE + 0
CF_ERROR:   equ        CF_BASE + 1
CF_SECTORS: equ        CF_BASE + 2
CF_LBA0:    equ        CF_BASE + 3
CF_LBA1:    equ        CF_BASE + 4
CF_LBA2:    equ        CF_BASE + 5
CF_LBA3:    equ        CF_BASE + 6
CF_CMD:     equ        CF_BASE + 7

; ** Key Command Definititions **
CF_CMD_READ:    equ        $20         ; - Read sectors with retry
CF_CMD_WRITE:   equ        $30         ; - Write sectors with retry
CF_CMD_ID:      equ        $EC         ; - Identify drive
CF_CMD_FEATURE: equ        $EF         ; - Set Feature


; cf_init - initializes the CF interface. Enables 8-bit mode and disables write caching
; affects: A
cf_init:        call    cf_wait_ready       ; wait for CF card to be ready

                ld      a, $01              ; write 0x01 (= enable 8-bit mode) to DATA register
                out     (CF_DATA), a
                ld      a, CF_CMD_FEATURE   ; write "set feature" command to COMMAND register
                out     (CF_CMD), a

                ld      a, $82              ; write 0x82 (= disable write caching) to DATA register
                out     (CF_DATA), a
                ld      a, CF_CMD_FEATURE   ; write "set feature" command to COMMAND register
                out     (CF_CMD), a

                ret

; cf_wait_ready - waits for BUSY = 0 and RDY = 1
; affects: A
cf_wait_ready:  in      a, (CF_CMD)         ; read STATUS
                and     %11000000           ; mask off busy(7) and ready(6) bits
                xor     %01000000           ; want BUSY = 0 and RDY = 1
                jr      nz, cf_wait_ready   ; if Z the above is met
                ret

; cf_wait_data_ready - waits for BUSY = 0 and DRQ = 1
; affects: A
cf_wait_data_ready:
                in      a, (CF_CMD)         ; read STATUS
                and     %10001000           ; mask off busy(7) and drq(3) bits
                xor     %00001000           ; want BUSY = 0 and DRQ = 1
                jr      nz, cf_wait_ready   ; if Z the above is met
                ret

; cf_check_error - reads error status and codes
; affects: A
; returns: Carry flag set if error
cf_check_error: in      a, (CF_CMD)         ; read STATUS register
                and     %00000001           ; check bit 0, Z = bit 0. This also clears the carry flag (yay!)
                ret     Z                   ; no error (bit = 0) => return

                in      a, (CF_ERROR)       ; there was an error, read the error register
                scf                         ; set carry flag to indicate error

                rst     30H                 ; BREAK to see the error status bits, TODO: make this better
                ret

; cf_read_id - reads the drives ID area using the "Identify Drive" command to the specified memory location in HL
; parameters: HL - start of 512 byte area where CF ID sector is read to
; affects: A, BC, HL
; returns: none
cf_read_id:     call    cf_wait_ready       ; wait for device ready

                ld      a, CF_CMD_ID
                out     (CF_CMD), a         ; write "Drive ID Command" to COMMAND register

                call    cf_wait_data_ready  ; wait for data to be ready

                call    cf_check_error      ; check error flags
                ret     C                   ; return if error

                ; read data
                ld      c, CF_DATA          ; port to read from
                ld      b, 0                ; number of bytes to read, 0 means 256
                inir                        ; read first 256 bytes: (HL) <- [C]; B <- B-1; HL <- HL+1; Repeat while B>0
                inir                        ; read second 256 bytes: (HL) <- [C]; B <- B-1; HL <- HL+1; Repeat while B>0

                ret                         ; return

; cf_set_lba_address - sets the LBA (Logical Block Addressing) address to the address in XX, thus 2^16=65536 blocks are addressable. 
; With 512 bytes/block this means a total of 2^16 * 2^9 = 2^25 bytes = 2^5 MiB = 32 MiB can be addressed
cf_set_lba_address:


                ret

; cf_read_sector - reads the sector of 512 bytes specified in cf_set_lba_address from the CF card into ram, starting at the address in HL
; parameters: HL - start of 512 byte ram area to read sector into
; returns: none
cf_read_sector: 
                
                ret


; cf_write_sector - writes the sector of 512 bytes specified in cf_set_lba_address to the CF card from ram starting at the address in HL
; parameters: HL - start of 512 byte ram area to write to sector
; returns: none
cf_write_sector:

                ret

