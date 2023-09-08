            .cpu    "65c02"

copy        .namespace

debug = 0
buffer_len = 128

            .virtual 0
state_open_src      .byte   ?
state_open_dest     .byte   ?
state_read          .byte   ?
state_write         .byte   ?
state_delete_dest   .byte   ?
state_close_dest    .byte   ?
state_close_src     .byte   ?
state_exit          .byte   ?
            .endv

            .section    data
src_stream  .byte       ?
dest_stream .byte       ?
dest_drive  .byte       ?
buf_offset  .byte       ?
to_write    .byte       ?
failed      .byte       ?
state       .byte       ?
            .send

            .section    code

cmd
          ; Initialize status variables
            stz     src_stream
            stz     dest_stream
            stz     buf_offset
            stz     failed

          ; This command requires two arguments
            lda     readline.token_count
            cmp     #3
            sec     ; set error if not.
            bne     _fail

          ; Kick off the operation
            stz     state
            jsr     action.open_src

        .if debug==1
            lda     #10
            jsr     display.putchar
        .endif

_event_loop
            jsr     kernel.NextEvent
            bcs     _event_loop

            jsr     event_handler.dispatch

        .if debug==1
            lda     #10
            jsr     display.putchar
        .endif

            lda     state
            cmp     #state_exit
            bne     _event_loop

_exit
            lda     failed
            bne     _fail

            clc
            rts
_fail
            sec
            rts

event_handler .namespace

dispatch    
        .if debug==1        
            lda     state
            jsr     display.print_hex
            lda     #','
            jsr     display.putchar
            lda     event.type
            jsr     display.print_hex
            lda     #':'
            jsr     display.putchar
        .endif

            lda     failed
            bne     fail_dispatch

            lda     event.type
            cmp     #kernel.event.file.OPENED
            beq     on_opened
            cmp     #kernel.event.file.CLOSED
            beq     on_closed
            cmp     #kernel.event.file.NOT_FOUND
            beq     on_not_found
            cmp     #kernel.event.file.ERROR
            beq     on_error
            cmp     #kernel.event.file.DATA
            beq     on_data_read
            cmp     #kernel.event.file.WROTE
            beq     on_data_wrote
            cmp     #kernel.event.file.EOF
            beq     on_eof
            cmp     #kernel.event.key.PRESSED
            beq     on_key_pressed

        .if debug==1
            lda     #'!'
            jsr     display.putchar
        .endif

            rts

fail_dispatch
            lda     event.type
            cmp     #kernel.event.file.CLOSED
            beq     on_closed
            cmp     #kernel.event.file.DELETED
            beq     on_deleted

        .if debug==1
            lda     #'*'
            jsr     display.putchar
        .endif
            rts


on_opened
            jmp     on_opened_long
on_key_pressed
            jmp     on_key_pressed_long
on_data_read
            jmp     on_data_read_long
on_data_wrote
            jmp     on_data_wrote_long
on_eof
            jmp     on_eof_long
on_deleted
            jmp     on_deleted_long


on_error
on_not_found
        .if debug==1
            lda     event.file.stream
            jsr     display.print_hex
            lda     #' '
            jsr     display.putchar
        .endif
                            
fail
            lda     #1
            sta     failed

            lda     dest_stream
            bne     _close_dest
            lda     src_stream
            bge     _close_src

            lda     #state_exit
            sta     state
            rts

_close_src
            lda     #state_close_src
            sta     state
            jmp     action.close_src

_close_dest
            lda     #state_close_dest
            sta     state
            jmp     action.close_dest


on_closed
        .if debug==1
            lda     event.file.stream
            jsr     display.print_hex
            lda     #' '
            jsr     display.putchar
        .endif

          ; A file was closed
            lda     state
            cmp     #state_close_dest
            beq     _dest
            cmp     #state_close_src
            beq     _src
            rts

_dest
          ; Dest was closed, move on to src
            lda     #state_close_src
            sta     state
            jmp     action.close_src

_src
          ; Src was closed, move on to delete dest if operation was marked
          ; failed, else exit
            lda     failed
            beq     _exit
            lda     #state_delete_dest
            sta     state
            jmp     action.delete_dest
_exit
            lda     #state_exit
            sta     state
            rts


on_eof_long
          ; Handle EOF, this should always be the source file
            lda     state
            cmp     #state_read
            bne     _exit

            lda     #state_close_dest
            sta     state
            jmp     action.close_dest
_exit     
            rts


on_deleted_long
            lda     #state_exit
            sta     state
            rts
            

on_data_read_long
          ; Handle data read event. We copy the data here as the ReadData call is not async
        .if debug==1
            lda     #'r'
            jsr     display.putchar
            lda     event.file.data.read
            jsr     display.print_hex
            lda     #' '
            jsr     display.putchar
        .endif
          
          ; Save the number of bytes read
            lda     event.file.data.read
            sta     to_write

          ; Set the buffer length
            sta     kernel.args.buflen

          ; Set the buffer pointer
            lda     #<buf
            sta     buf_offset
            sta     kernel.args.buf+0
            lda     #>buf
            sta     kernel.args.buf+1

            jsr     kernel.ReadData

            lda     #state_write
            sta     state
            jmp     action.write


on_data_wrote_long
        .if debug==1
            lda     #'w'
            jsr     display.putchar
            lda     event.file.wrote.wrote
            jsr     display.print_hex
            lda     #' '
            jsr     display.putchar
        .endif

          ; Some bytes were written, update pointers and remaining count
            lda     to_write
            sec
            sbc     event.file.wrote.wrote
            beq     _done
            sta     to_write

            lda     buf_offset
            clc
            adc     event.file.wrote.wrote
            sta     buf_offset

            jmp     action.write

_done
            jmp     first_read


on_opened_long
        .if debug==1
            lda     event.file.stream
            jsr     display.print_hex
            lda     #' '
            jsr     display.putchar
        .endif

            lda     state
            cmp     #state_open_src
            beq     _src
            cmp     #state_open_dest
            beq     _dest
            rts

_src
            lda     #state_open_dest
            sta     state
            jmp     action.open_dest

_dest       ; _dest fall through to first_read
first_read
            lda     #state_read
            sta     state
            jmp     action.read


on_key_pressed_long
            lda     event.key.raw
            cmp     #ESC
            bne     _exit

            jmp     fail
_exit
            rts


            .endn


action     .namespace

delete_dest
            lda     dest_drive
            sta     kernel.args.file.delete.drive

            lda     readline.tokens+2
            sta     kernel.args.file.open.fname+0
            lda     #>readline.buf
            sta     kernel.args.file.open.fname+1

          ; Set the filename length
            lda     #2
            jsr     readline.token_length
            beq     action.fail
            sta     kernel.args.file.open.fname_len

            jmp     kernel.File.Delete


open_src
          ; Open source file
        .if debug==1
            lda     #'+'
            jsr     display.putchar
        .endif

            lda     #1  ; Token #1
            ldx     #kernel.args.file.open.READ
            jsr     operations.open_file
            bcs     fail
            sta     src_stream
        .if debug==1
            jsr     display.print_hex
        .endif

_exit       rts        


fail
            jmp     event_handler.fail

open_dest
          ; Open destination file
        .if debug==1
            lda     #'+'
            jsr     display.putchar
        .endif

            lda     #2  ; Token #2
            ldx     #kernel.args.file.open.WRITE
            jsr     operations.open_file
            bcs     fail
            sta     dest_stream
            lda     kernel.args.file.open.drive
            sta     dest_drive

        .if debug==1
            jsr     display.print_hex
        .endif
            rts


close_dest
            lda     dest_stream
            jmp     operations.close_file


close_src
            lda     src_stream
            jmp     operations.close_file


read
        .if debug==1
            lda     #'R'
            jsr     display.putchar
            lda     #buffer_len
            jsr     display.print_hex
            lda     #' '
            jsr     display.putchar
        .endif

          ; Set the stream
            lda     src_stream
            sta     kernel.args.file.read.stream

          ; Set the buffer length
            lda     #buffer_len
            sta     kernel.args.file.read.buflen

          ; Call read
            jsr     kernel.File.Read
            bcs     fail
            rts


write
        .if debug==1
            lda     #'W'
            jsr     display.putchar
            lda     to_write
            jsr     display.print_hex
            lda     #' '
            jsr     display.putchar
        .endif

          ; Set the stream
            lda     dest_stream
            sta     kernel.args.file.write.stream

          ; Set the buffer pointer
            lda     buf_offset
            sta     kernel.args.file.write.buf+0
            lda     #>buf
            sta     kernel.args.file.write.buf+1

          ; Set the buffer length
            lda     to_write
            sta     kernel.args.file.write.buflen

          ; Call write
            jmp     kernel.File.Write


            .endn


operations  .namespace

; A - token
; X - mode
open_file
            phx

          ; Set the drive
            pha
            jsr     readline.parse_drive
            sta     kernel.args.file.open.drive

          ; Set the filename pointer
            plx
            phx
            lda     readline.tokens,x
            sta     kernel.args.file.open.fname+0
            lda     #>readline.buf
            sta     kernel.args.file.open.fname+1

          ; Set the filename length
            pla
            jsr     readline.token_length
            tay
            beq     action.fail
            sta     kernel.args.file.open.fname_len

          ; Open the file for create/overwrite
            pla
            sta     kernel.args.file.open.mode
            jmp     kernel.File.Open


; A - stream id
close_file
            tay
            beq     _closed
            sta     kernel.args.file.close.stream
            jmp     kernel.File.Close
_closed
            rts 


            .endn



            .send
            .endn
