            .cpu    "65c02"

help        .namespace

            .mkstr  doshdr,x"0A".."DOS commands:"

            .section    code

cmd
            phx
            phy

            lda     #doshdr_str
            jsr     puts_hdr

            lda     #>_msg
            ldx     #<_msg
            jsr     strings.puts_zero

            ply
            plx
            clc
            rts        

_msg
            .text   "<digit>:            Change drive.", $0a
            .text   "ls                  Shows the directory.",$0a
            .text   "dir                 Shows the directory.",$0a
            .text   "lsf                 Shows programs resident in flash memory.",$0a
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

