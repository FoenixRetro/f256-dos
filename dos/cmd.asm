            .cpu    "65c02"

            ; Globals
            
            .section    pages
buf         .fill       256     ; Used to fetch data from the kernel.
            .send

            .section    data
drive       .byte       ?                       ; Current selected (logical) drive #
event       .dstruct    kernel.event.event_t    ; Event data copied from the kernel
            .send

cmd         .namespace
        
            .mkstr  devlist,    "Registered File-System devices: "
            .mkstr  nolist,     "No drives found."
            .mkstr  unknown,    "Unknown command."
            .mkstr  failed,     "Command failed."
            .mkstr  help,       "Enter 'help' for help, 'about' for information about this software."
            .mkstr  bad_drive,  "Drive number must be in [0..7]."
            .mkstr  no_drive,   "Drive not found."

            .section    dp
eol         .byte       ?
drives      .byte       ?
tmp         .word       ?
            .send            

            .section    data
prompt_len  .byte       ?
prompt_str  .fill       8
            .send

            .section    code

words       .namespace
            .align  256
base        .null   ""      ; So offset zero is invalid
help        .null   "help"
about       .null   "about"
ls          .null   "ls"
dir         .null   "dir"
lsf         .null   "lsf"
read        .null   "read"
write       .null   "write"  
dump        .null   "dump" 
rename      .null   "rename"   
cp          .null   "cp"   
rm          .null   "rm"     
del         .null   "del"     
delete      .null   "delete"     
mkfs        .null   "mkfs"
keys        .null   "keys"
mkdir       .null   "mkdir"     
rmdir       .null   "rmdir"     
wifi        .null   "wifi"
            .endn

commands
            .word   words.help,     help.cmd
            .word   words.about,    about
            .word   words.ls,       dir.cmd
            .word   words.dir,      dir.cmd
            .word   words.lsf,      lsf.cmd
            .word   words.read,     read.cmd
            .word   words.write,    write.cmd
            .word   words.dump,     dump.cmd
            .word   words.rename,   rename.cmd
            .word   words.cp,       copy.cmd
            .word   words.rm,       delete.cmd
            .word   words.del,      delete.cmd
            .word   words.delete,   delete.cmd
            .word   words.mkfs,     mkfs.cmd
            .word   words.keys,     keys.cmd
            .word   words.mkdir,    mkdir.cmd
            .word   words.rmdir,    rmdir.cmd
            .word   words.wifi,     wifi.cmd
            .word   0

about
            jsr     hardware
            jsr     ukernel
            jsr     fat32
            rts        
hardware    
            phx

            lda     #>_msg
            ldx     #<_msg
            jsr     strings.puts_zero

            plx
            rts        
_msg
            .text   $0a
            .text   "Foenix F256 by Stefany Allaire", $0a
            .text   "https://c256foenix.com/f256-jr",$0a
            .text   $0a, $00

ukernel            
            phx

            lda     #>_msg
            ldx     #<_msg
            jsr     strings.puts_zero

            lda     #$E0
            ldx     #$08
            jsr     strings.puts_zero

            jsr     put_cr
            jsr     put_cr

            plx
            rts        
_msg
            .text   "TinyCore MicroKernel", $0a
            .text   "Copyright 2022 Jessie Oberreuter", $0a
            .text   "Gadget@HackwrenchLabs.com",$0a
            .text   "Built/revision: ",0

fat32
            phx

            ldx     #<_msg
            lda     #>_msg
            jsr     strings.puts_zero

            plx
            rts        

_msg
            .text   "Fat32 from https://github.com/commanderx16/x16-rom", $0a
            .text   "Copyright 2020 Frank van den Hoef and Michael Steil", $0a
            .text   $0a
            .text   "Simple DOS Shell, built ", DATE_STR, $0a
            .byte   $0
            

start
          ; Tell the event call where to dump events.
            lda     #<event
            sta     kernel.args.events+0
            lda     #>event
            sta     kernel.args.events+1

          ; Get the list of drives
            jsr     kernel.FileSystem.List
            sta     drives

          ; Print the list of drives
            jsr     print_drives

          ; Print the help text.
            lda     #help_str
            jsr     puts_cr

          ; Select the initial drive
            stz     drive

          ; Jump to the command loop
            jmp     run
            
print_drives
            lda     drives
            bne     _list
        
            lda     #nolist_str
            jmp     puts_cr

_list
            lda     #devlist_str
            jsr     puts
        
            lda     drives
            ldx     #'0'-1
_loop        
            lsr     a
            inx
            bcc     _next
            pha
            txa
            jsr     putc
            pla
_next
            bne     _loop
            jmp     put_cr
                
               
run
            jsr     put_cr
            jsr     prompt
            jsr     readline.read
            lda     readline.length
            cmp     #2
            bne     _cmd
            lda     readline.buf+1
            cmp     #':'
            bne     _cmd
            jmp     set_drive
_cmd
            jsr     readline.tokenize
            lda     readline.token_count
            beq     run
        
            jsr     dispatch
            bcc     _next
            
            jsr     put_cr
            lda     #failed_str
            jsr     puts_cr
_next
            bra     run


set_drive
            lda     readline.buf

            cmp     #'0' 
            bcc     _nope   

            cmp     #'7'+1 
            bcs     _nope   

            and     #7
            tay
            lda     _bits,y
            bit     drives
            beq     _unknown

            sty     drive
            bra     _done
_unknown
            lda     #no_drive_str
            jsr     strings.puts             
            jmp     _done
_bits       .byte   1,2,4,8,16,32,64,128            

_nope
            lda     #bad_drive_str
            jsr     strings.puts
_done
            jmp     run            

prompt
            jsr     set_prompt

            lda     #$24
            sta     display.color

            ldy     #0
_loop
            lda     prompt_str,y
            beq     _done
            jsr     display.putchar
            iny
            bra     _loop
_done
            sty     prompt_len
            sty     eol

            lda     #$14
            sta     display.color

            rts
             
set_prompt
            lda     drive
            clc
            adc     #'0'
            sta     prompt_str+0
            lda     #':'
            sta     prompt_str+1
            stz     prompt_str+2
            rts

dispatch
            ldy     readline.tokens+0   ; offset of token zero.
            lda     readline.buf,y
            cmp     #'/'
            bne     _check_internal
            inc     readline.tokens+0
            bra     _check_user_program

_check_internal
            ldx     #0
_cmd
            lda     commands,x
            beq     _check_user_program
            inx
            inx        

            ldy     readline.tokens+0   ; offset of token zero.
            jsr     _cmp
            bcs     _next
            jmp     (commands,x)

_next        
            inx
            inx
            bra     _cmd

_check_user_program
          ; Set up argument array for user programs
            jsr     readline.populate_arguments

          ; See if it's the name of a binary
            lda     readline.tokens+0
            sta     kernel.args.buf+0
            lda     #>readline.buf
            sta     kernel.args.buf+1
            lda     #0
            jsr     readline.token_length
            tay
            lda     #0
            sta     (kernel.args.buf),y
            jsr     kernel.RunNamed

          ; Try to load an external user program on disk, kernel.args.buf is already initialized
            jsr     external.cmd
            bcs     _unknown_cmd
            rts
_unknown_cmd

          ; If the chain failed, unknown command.
            lda     #unknown_str
            jsr     strings.puts
            jsr     put_cr
            clc
            rts
        
_cmp
    ; a->offset in words
    ; y->token start

            phx
            tax

_loop
            lda     words.base,x
            cmp     readline.buf,y
            bne     _nope
            ora     readline.buf,y
            clc
            beq     _out
            inx
            iny
            bra     _loop
_nope
            sec
_out
            plx
            rts

            .send
            .endn
