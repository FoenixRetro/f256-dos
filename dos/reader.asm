	            .cpu    "65c02"

reader      .namespace

            .mkstr  not_found,  "File not found."

            .section    data
stop        .byte       ?
read_len    .byte       ?
print_fn    .byte       ?
remaining   .byte       ?
            .send            

            .section    code

read_file
    ; A = # of bytes to fetch at a time
    ; X -> print function pointer in ZP.

          ; Stash the read size and print function
            sta     read_len
            sta     remaining
            stx     print_fn

          ; This command requires an argument
            lda     readline.token_count
            cmp     #2
            bne     _error

          ; Clear the stop flag
            stz     stop

          ; Set the drive 
            lda     #1  ; Token #1
            jsr     readline.parse_drive
            sta     kernel.args.file.open.drive

          ; Set the filename (conveniently aligned)
            lda     readline.tokens+1
            sta     kernel.args.file.open.fname+0            
            lda     #>readline.buf
            sta     kernel.args.file.open.fname+1

          ; Set the filename length
            lda     #1  ; Token #1
            jsr     readline.token_length
            beq     _error
            sta     kernel.args.file.open.fname_len

          ; Set the mode and open.
            lda     #kernel.args.file.open.READ
            sta     kernel.args.file.open.mode
            jsr     kernel.File.Open
            bcs     _error
_loop
            lda     kernel.args.events.pending
            beq     _loop
            ;jsr     kernel.Yield    ; Not required; but good while waiting.
            jsr     kernel.NextEvent
            bcs     _loop

            lda     event.type  
            cmp     #kernel.event.file.CLOSED
            beq     _done
            cmp     #kernel.event.file.NOT_FOUND
            beq     _not_found
            cmp     #kernel.event.file.ERROR
            beq     _not_found

            jsr     _dispatch
            bra     _loop
_error
          ; The command loop will print the error.
            sec
            rts
_done
            jsr     put_cr
            clc
            rts

_dispatch
            cmp     #kernel.event.file.OPENED
            beq     _read
            cmp     #kernel.event.file.DATA
            beq     _data
            cmp     #kernel.event.file.EOF
            beq     _eof
            cmp     #kernel.event.key.PRESSED
            beq     _key
            rts

_not_found
            lda     #not_found_str
            jmp     puts_cr

_key
    ; Pressing any key will request an early end and close.
            lda     event.key.ascii
            sta     stop
            rts            
_read
    ; Read data from the file

          ; If a stop has been requested, close instead.
            lda     stop
            bne     _eof

          ; Set the stream
            lda     event.file.stream
            sta     kernel.args.file.read.stream

          ; Set the read size; adjusts for cosmetic reasons.
            lda     remaining
            bne     _set
            lda     read_len
_set        sta     kernel.args.file.read.buflen

          ; Request the data
            jmp     kernel.File.Read

_data
          ; Print the data
            jsr     data

          ; Reuqest the next read.  If remaining is non-zero,
          ; continues to work it down to zero.  This is really
          ; just to make cmd_dump look pretty.
            lda     remaining
            beq     _read
            sec
            sbc     event.file.data.read
            sta     remaining
            bra     _read

_eof
            lda     event.file.stream
            sta     kernel.args.file.close.stream
            jmp     kernel.File.Close
            
data
          ; Get the data from the kernel
            lda     event.file.data.read
            jsr     read_data

          ; Print it.
            ldy     #0
_loop       lda     buf,y
            jsr     print
            iny
            cpy     event.file.data.read
            bne     _loop
_done
            rts

read_data
    ; IN: A = # of bytes to import from the event
    
            sta     kernel.args.recv.buflen

            lda     #<buf
            sta     kernel.args.recv.buf+0
            lda     #>buf
            sta     kernel.args.recv.buf+1

            jmp     kernel.ReadData

print
            ldx     print_fn
            jmp     (0,x)

            .send
            .endn

