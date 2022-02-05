;; Second stage boot loader for booting a Victor 9000 / Sirius 1 over RS232

;; Copyright 2022 by Chris Osborn <fozztexx@fozztexx.com>
;;
;; This file is part of cerealbewt.
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 2 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License at <http://www.gnu.org/licenses/> for
;; more details.

        cpu 8086

	ROMSIZE		equ 512
	SCREEN		equ 0F000h	; address of screen ram
	IO_7201		equ 0E004h	; address of NEC 7201 registers
	IO_6522		equ 0E804h	; address of 6522 registers
	IO_8253		equ 0E002h	; address of Intel 8253 registers
	
	A_DATA		equ 0
	A_CTL		equ 2
	ERR_CHK		equ 000001b	; checks for receive errors
	DATA_AVAIL	equ 1		; data available at the chip
	ANY_ERRORS	equ 30h		; error status bits
	
	org 04000h

start:
	;; Serial port should already be initialized from ROM

	;; mov ax,IO_7201
	;; mov es,ax
	;; call flushtx
	
	;; ;; Disable parity
	;; mov byte [es:A_CTL],4
	;; mov byte [es:A_CTL],01000100b
	
	;; change the baud rate
	mov ax,IO_8253
	mov es,ax
	mov byte [es:3],36h
	mov byte [es:0],04h	; 0004 = 19200  0041 = 1200
	mov byte [es:0],0
	
	mov dx,SCREEN
	mov es,dx
	mov si,80*2

	push si
	mov cx,80*2*10		; Clear first 10 lines
	mov ax,31
clearscreen:	
	mov [es:si],ax
	inc si
	loop clearscreen
	pop si
	
	;; Display all characters available in font
	mov cx,80
	xor ax,ax
allchars:
	mov [es:si],ax
	inc ax
	add si,2
	loop allchars

	;; call newline

	mov cx,msglen
	mov bx,msg
	mov ax,0
.loop:
	mov al,[cs:bx]
	add al,32
	call putch
	inc bx
	loop .loop
	;; call newline

	call readser
	mov ax,28+32
	call putch
	mov ax,29+32
	call putch
ready:	
	mov cx,rdylen
	mov bx,rdy
.loop:
	mov al,[cs:bx]
	call writeser
	inc bx
	loop .loop

	;; read length and destination address
	mov cx,7
	mov bx,length
getal:
	call readser
	mov [cs:bx],al
	inc bx
	loop getal

	add si,2
	
	mov ax,[dest+2]
	cmp ax,0FFFFh
	jnz nottop

	;; change dest to be top of RAM minus length
	xor ax,ax
	mov [dest],ax
	mov cx,4
	mov ax,[length]
	add ax,15		; round up to nearest paragraph
	shr ax,cl
	mov bx,[length+2]
	shr bx,cl
	add bx,ax
	mov ax,[bvt+memsz]
	sub ax,bx
	mov [dest+2],ax
nottop:	
	call puthex16
	add si,2

	mov ax,[dest]
	call puthex16
	add si,2

	;; Display length
	mov al,[length+2]
	call puthex
	mov ax,[length]
	call puthex16
	add si,2

	mov cx,[length]
	xor bh,bh
	mov bl,[length+2]

	mov ax,cs
	mov ds,ax
	mov di,bootend
	push ds			; save buffer segment
	push di			; save buffer offset
serloop:
	mov ax,bx
	call puthex
	mov ax,cx
	call puthex16
	add si,2
	call readser
	mov [ds:di],al
 	call puthex
	sub si,(6+1+2)*2
	inc di
	jnz nocross
	mov ax,ds
	add ax,4096
	mov ds,ax
nocross:
	loop serloop
	dec bx
	jns serloop

	;; Display arrow to indicate download complete
	call newline
	mov ax,18+32
	call putch
	mov ax,19+32
	call putch

bootreloc:
	mov ax,ds
	call puthex16
	mov ax,di
	call puthex16
	
	mov ax,ds		; Download end segment
	mov bx,di		; Download end offset
	mov cx,4
	shr bx,cl
	add ax,bx
	inc ax

	push si			; save cursor position
	
	mov bx,cs
	mov ds,bx		; source segment
	lea si,start		; source offset
	mov es,ax		; dest segment
	xor di,di		; dest offset

	mov cx,bootend-start	; length
	cld
	rep movsb

	;; jump to moved bootstrap
	push es
	mov ax,binmove-start
	push ax
	retf

binmove:
	;; Display hard drive icon to indicate going to move binary to dest
	pop si			; restore cursor position
	call newline
	mov ax,26+32
	call putch
	mov ax,27+32
	call putch

	;; ;; DEBUG - display source segment:offset
	;; pop bx			; buffer begin offset
	;; pop ax			; buffer begin segment
	;; push ax			; put them back for later
	;; push bx
	;; call puthex16
	;; add si,2
	;; mov ax,bx
	;; call puthex16
	;; ;; DEBUG - display dest segment:offset
	;; add si,4
	;; mov ax,[dest+2]
	;; call puthex16
	;; add si,2
	;; mov ax,[dest]
	;; call puthex16

	;; move downloaded binary to dest
	pop si			; buffer begin offset
	pop ds			; buffer begin segment
	mov es,[dest+2]
	mov di,[dest]
	mov bx,[length+2]
	mov cx,[length]
	cld
.loop:
	rep movsb
	dec bx
	jns .loop

	;; Jump to binary using ROM INT method
	;; xor ax,ax
	;; mov ds,ax
	;; mov ax,[dest]
	;; mov cx,[dest+2]

	;; mov ds:255*4,ax
	;; mov ds:255*4+2,cx
	;; int 255

	;; Jump to binary by doing a far return
	mov ax,[dest]
	mov cx,[dest+2]
	push cx
	push ax
	retf

putch:
	mov es,dx
	mov [es:si],ax
	add si,2
	ret

puthex16:
	push ax
	mov al,ah
	call puthex
	pop ax
puthex:
	push ax
	push ax
	xor ah,ah
	shr al,1
	shr al,1
	shr al,1
	shr al,1
	add al,32
	call putch
	pop ax
	xor ah,ah
	and al,0fh
	add al,32
	call putch
	pop ax
	ret

newline:
	push dx			; save screen segment
	mov bx,80*2
	xor dx,dx
	mov ax,si
	div bx
	mul bl
	add ax,bx
	mov si,ax
	pop dx
	ret

readser:
	mov ax,IO_7201
	mov es,ax
readwait:	
	test [es:A_CTL],byte DATA_AVAIL
	jz readwait

do_read:
	mov al,[es:A_DATA]
	mov [es:A_CTL],byte ERR_CHK
	mov ah,[es:A_CTL]
	and ah,ANY_ERRORS
	mov [es:A_DATA],al
	ret

writeser:
	push ax
	mov ax,IO_7201
	mov es,ax
	pop ax
	mov [es:A_DATA],al
flushtx:				
	test [es:A_CTL],byte 04h	; Wait for byte to transmit
	jz flushtx
	ret
	
msg:	db  15,0,2,2,18,19,14,24,25,24,25
msglen	equ $-msg
rdy:	db "READY",0dh,0ah
rdylen	equ $-rdy

length:	db 3 dup (0)
dest:	db 4 dup (0)		; Allow room for 4 byte segment:offset

; pad out the ROM
times ROMSIZE-($-$$) db 05Ah

	bootend equ $

	;; Victor ROM variables

	struc	boot_table
	memsz 	resw 1		; size of memory, in paragraphs
	btdrv 	resw 1		; boot drive
	dvclst	resw 2		; long pointer to list of devices
	dvccbs	resw 2		; long pointer to device control blocks
	nfatals	resw 2		; flag word for non-fatal errors
	endstruc

	struc 	load_request_block
	op	resw 1		; Operation Code                       
	dun	resw 1		; Device/Unit Number                   
	da	resw 2		; Physical Address on Volume           
	dma	resw 2		; Direct Memory Address                
	blkcnt	resw 1		; Number of Blocks in Transfer         
	status	resb 1		; STATUS code returned
	ssz	resw 1		; Sector Size                          
	laodaddr resw 1		; Segment to Load into - 0 => Load High
	loadpara resw 1		; Paragraph Count                      
	loadentry resw 2	; Entry Point - Seg=0 => Use "loadaddr"
	endstruc	  
			  
	absolute 0300h

bvt:	istruc boot_table
lrb:	istruc load_request_block
