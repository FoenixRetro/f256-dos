            .cpu    "65c02"

help        .namespace

            .mkstr  doshdr,x"0A".."DOS commands:"
            .mkstr  flashhdr,"Flash resident programs:"

            .section    code

cmd
            phx
            phy

            lda     #doshdr_str
            jsr     puts_hdr

            lda     #>_msg
            ldx     #<_msg
            jsr     strings.puts_zero

            lda     #flashhdr_str
            jsr     puts_hdr

            lda     #$B3    ; edit and activate #3
            sta     $00

            ; search expansion ram/rom
            lda     #$80
            sta     $09     ; set slot 1 ($2000)
            ldy     #$40
            jsr     _print_next

            ; search flash
            lda     #$40
            sta     $09     ; set slot 1 ($2000)
            ldy     #$40
            jsr     _print_next

            ; disable edit
            lda     #$33
            sta     $00

            ply
            plx
            rts        

_print_next jsr     _print_program
            inc     $09     ; point MMU slot #1 at next block
            dey
            bne     _print_next
            rts

_print_program
            ; check if program
            phy
            lda     $2000
            cmp     #$F2
            bne     _not_kup
            lda     $2001
            cmp     #$56
            bne     _not_kup

            ; print name
            lda     $09
            sec
            sbc     #$40
            jsr     display.print_hex
            lda     $2002
            cmp     #2
            blt     _one_block
            lda     #"-"
            jsr     putc
            lda     $09
            clc
            adc     $2002
            sbc     #$40
            jsr     display.print_hex
_one_block  lda     #6
            jsr     _skip_to_column

            ldx     #0
_print_name lda     $200A,x
            beq     _name_done
            jsr     putc
            inx
            bra     _print_name
_name_done

            ; is header version >= 1?
            lda     $2006
            beq     _no_info

            lda     #13
            jsr     _skip_to_column

            ; found info at $200B+X
            ; print argument string
_print_arg_char
            lda     $200B,x
            beq     _print_arg_done
            jsr     putc
            inx
            bra     _print_arg_char
_print_arg_done
            lda     #24
            jsr     _skip_to_column

            ; print description string
_print_desc_char
            lda     $200C,x
            beq     _print_desc_done
            jsr     putc
            inx
            bra     _print_desc_char
_print_desc_done

_print_done
_no_info
            jsr     put_cr
_not_kup
            ply
            rts

            ; skip to column number in A
_skip_to_column
            tay
            dey
_skip_to_next_column
            cpy     display.cursor
            blt     _column_skip_done
            lda     #' '
            jsr     putc
            bra     _skip_to_next_column
_column_skip_done
            rts

_msg
            .text   "<digit>:            Change drive.", $0a
            .text   "ls                  Shows the directory.",$0a
            .text   "dir                 Shows the directory.",$0a
            .text   "read   <fname>      Prints the contents of <fname>.", $0a
            .text   "write  <fname>      Writes user input to <fname>.", $0a
            .text   "dump   <fname>      Hex-dumps <fname>.", $0a
            .text   "rm     <fname>      Delete <fname>.", $0a
            .text   "del    <fname>      Delete <fname>.", $0a
            .text   "delete <fname>      Delete <fname>.", $0a
            .text   "rename <old> <new>  Rename <old> to <new>.", $0a
            .text   "cp     <old> <new>  Copy <old> to <new>.", $0a
            .text   "mkfs   <label>      Creates a new filesystem on the device.", $0a
            .text   "keys                Demonstrates key status tracking.", $0a
            .text   "help                Prints this text.", $0a
            .text   "about               Information about the software and hardware.", $0a
            .text   "wifi <ssid> <pass>  Configures the wifi access point.", $0a
            .text   $0a
            .byte   $0



            .send
            .endn

