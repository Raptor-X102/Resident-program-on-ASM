.model tiny
.code
.386
org 100h
LOCALS @@
VIDEO_MEM_SEGMENT equ 0b800h
COMMAND_STR_OFFSET equ 81h
USER_FORMAT_NUM equ 0h
WINDOW_HEIGHT equ 18h
WINDOW_WIDTH equ 50h
FRAME_HEIGHT equ 16h
FRAME_WIDTH equ 40h
FRAME_COLOUR equ 1ch
REG_STR_OFFSET_1 equ 5
REG_STR_OFFSET_2 equ 7
NEW_LINE_SEG_OFFSET equ 0ah
DEC_BASE equ 0ah
OFFSET_RATIO equ 5h
VIDEO_MEM_SEG equ 0b800h
CALL_BUTTON equ 29h
EXIT_BUTTON equ 4fh

Start:
        xor ax, ax      ; | table of interruptions starts from 0
        mov es, ax      ; |

        mov bx, 09h*4    ; (1)  | each interruption is specified by segment and offset => 4 bytes

		cli		; restricts interruption processing
        mov ax, es:[bx]
        mov word ptr cs:[Func_offset1], ax        ; saving to a variable offset of initial function (1)
        mov ax, es:[bx+2]
        mov word ptr cs:[Func_seg1], ax       ; saving to a variable segment of initial function (1)


        mov es:[bx], offset Draw_frame_main      ;puts offset of our func instead of int 09h func
        push ds
		;mov word ptr cs:[Tmp_DS], ds
        pop ax
        mov es:[bx+2], ax           ;puts segment of our func instead of int 09h func


		mov bx, 08h*4    ; (2)  | each interruption is specified by segment and offset => 4 bytes

        mov ax, es:[bx]
        mov word ptr cs:[Func_offset2], ax        ; saving to a variable offset of initial function (2)
        mov ax, es:[bx+2]
        mov word ptr cs:[Func_seg2], ax       ; saving to a variable segment of initial function (2)



        mov es:[bx], offset String_main      ;puts offset of our func instead of int 09h func
        push ds
        pop ax
        mov es:[bx+2], ax           ;puts segment of our func instead of int 09h func
        sti		; permits interruption processing

        mov ax, 3100h       ; int 21h 31h - makes resident
        mov dx, offset End_of_code

        shr dx, 4       ; size of program in paragraphs
        inc dx          ; exclude division reduce
        int 21h
;------------------------------------------------



;------------------------------------------------
; Draw_frame_main function, calls instead keyboard interruption handler
; Entry: None
; Exit:  None
; Destr: None
;------------------------------------------------
Draw_frame_main proc

		mov word ptr cs:[Tmp_AX], ax	; only ax is destroyed, that's why saving

        in al, 60h      ; puts in al last key
        cmp al, CALL_BUTTON
        jne @@Skip

		mov byte ptr cs:[Flag_value], 1b	; if CALL_BUTTON toggles Flag_value for timer interruption
		jmp @@Continue						; to draw frame
        @@Skip:

		cmp al, EXIT_BUTTON
		jne @@Continue

		mov byte ptr cs:[Flag_value], 0b	; if EXIT_BUTTON toggles Flag_value for timer interruption
											; to end updating
		@@Continue:

		mov ax, word ptr cs:[Tmp_AX]

        db 0eah     ; jmp to initial keyboard interruption handler

Func_offset1:      dw 0
Func_seg1:        dw 0

        endp
;------------------------------------------------



;------------------------------------------------
; String_main function, calls instead timer interruption handler
; Entry: None
; Exit:  None
; Destr: None
;------------------------------------------------
String_main	proc

		mov word ptr cs:[Tmp_AX], ax

		mov al, byte ptr cs:[Flag_value]
		cmp al, 0
		je @@Skip

		mov word ptr cs:[Tmp_BX], bx		; Saving all registers to variables
        mov word ptr cs:[Tmp_CX], cx
        mov word ptr cs:[Tmp_DX], dx
        mov word ptr cs:[Tmp_BP], bp
		mov word ptr cs:[Tmp_SP], sp
        mov word ptr cs:[Tmp_SI], si
		mov word ptr cs:[Tmp_DI], di
		mov word ptr cs:[Tmp_ES], es
		mov word ptr cs:[Tmp_DS], ds


		mov bx, cs
		mov ds, bx		; program worked with ds initially by default
		mov si, offset Frame_style
        mov bp, FRAME_WIDTH
        mov dx, FRAME_HEIGHT
        mov ah, FRAME_COLOUR
        call Draw_Frame

        mov si, offset Tmp_AX
		push di dx bp
		mov di, offset Registr_string1 + REG_STR_OFFSET_1
		call Itoa_hex
		pop bp dx di

		mov si, offset Registr_string1
		call Write_String

		mov es, word ptr cs:[Tmp_ES]

		mov bx, word ptr cs:[Tmp_BX]
		mov cx, word ptr cs:[Tmp_CX]
		mov dx, word ptr cs:[Tmp_DX]
		mov bp, word ptr cs:[Tmp_BP]
		mov sp, word ptr cs:[Tmp_SP]
		mov si, word ptr cs:[Tmp_SI]
		mov di, word ptr cs:[Tmp_DI]
		mov ds, word ptr cs:[Tmp_DS]

		@@Skip:

		mov ax, word ptr cs:[Tmp_AX]
		db 0eah     ; jmp to initial timer interruption handler
Func_offset2:      dw 0        ; |
Func_seg2:        dw 0        ; |

		endp
;------------------------------------------------
Flag_value:		db 0


Tmp_AX:     dw 0h
Tmp_BX:     dw 0h
Tmp_CX:     dw 0h
Tmp_DX:     dw 0h
Tmp_BP:     dw 0h
Tmp_DI:     dw 0h
Tmp_SI:     dw 0h
End_of_print: db '$'
Tmp_SP:     dw 0h
Tmp_ES:     dw 0h
Tmp_DS:     dw 0h
Tmp_CS:     dw 0h

Registr_string1: db 'AX =     , BX =     , CX =     , DX =     , BP =     , '
				 db 'DI =     , SI =      $'
String: db 'One Piece is REEEEEEEAAAAALLLLL!!!$'
Frame_style: db '+-+I I\_/$'
			 db 3h, 3h, 3h, 3h, ' ', 3h, 3h, 3h, 3h, '$'

;------------------------------------------------
; Draws a frame with centered text
; Entry: SI - frame style string,
; 	 	 AH - frame colour, DX - height,
;	 	 BP - width
; Exit:  None
; Destr: BX ES CX
;------------------------------------------------

Draw_Frame	proc

		mov bx, WINDOW_HEIGHT
		sub bx, dx
		mov cx, bx
		shl bx, 2h		; |
		add bx, cx		; | --> mul 5
		add bx, VIDEO_MEM_SEGMENT		; with alignment
		mov es, bx

		mov di, WINDOW_WIDTH
		sub di, bp		; puts double left border offset, but each symbol is specified by 2 bytes

		sub dx, 2h		; | amount of symbols between borders
		sub bp, 2h		; |

		push es		; saving initial value of segment
		call Draw_Line		; drawing highest border
		mov bx, es
		add bx, NEW_LINE_SEG_OFFSET
		mov es, bx	 ; 160 bytes - string length, address += 10 * 16

		mov cx, dx
@@Loop:		; drawing lines of frame between borders
		push cx		; saving counter, it uses also in Draw_Line
		push si		; saving symbols to write
		call Draw_Line
		mov bx, es
		add bx, NEW_LINE_SEG_OFFSET
		mov es, bx
		pop si
		pop cx
		loop @@Loop

		add si, 3h		; moving to the last group of symbols
		call Draw_Line		; drawing lowest border
		pop es		;get initial video mem offset
		ret
		endp

;------------------------------------------------

;------------------------------------------------
; Draws a line with 3 symbols
; Entry: SI - string offset with symbols, AH - colour,
;		 BP - width, DI - offset in video-mem segment
; Exit: None
; Destr: BX, CX, SI, AL
;------------------------------------------------
Draw_Line	proc

		mov bx, di		; saving di
		lodsb
		stosw		; printing first symbol

		mov cx, bp
@@Loop:		; printing symbol of frame between
		mov al, ds:[si]
		stosw
		loop @@Loop

		inc si
		lodsb
		stosw		; printing last symbol
		mov di, bx
		;pop ds
		ret
		endp
;------------------------------------------------

;------------------------------------------------
; Prints a string
; Entry: SI - string offset, DX - height, BP -
;	 width, AH - colour, DI - offset in video-mem segment,
; Exit:  None
; Destr: BX, CX, DX, DI
;------------------------------------------------

Write_String	proc

		push ax
		mov ax, dx
		mov bx, ax		;
		shl ax, 2h		; |
		add ax, bx		; | --> mul 5, addr += height/2 * 160 = height * 80 = (height * 16) * 5
		mov bx, es
		add ax, bx
		mov es, ax		; es aligned to the center of window


		mov ax, bp
		mov dx, 0h
		mov bx, OFFSET_RATIO
		div bx	; |--> div 5. sum of offsets to string length ratio is 1 to 5


		mov bx, bp
		sub bx, ax		; bx now is a length of aligned line in frame
		push di
		mov di, si
		call Str_Len
		pop di
		mov dx, cx
		cmp dx, bx	; dx - real length of string
		jg @@Line_break

		mov bx, dx		;No line break
		mov ax, bp
		sub ax, bx
		mov bx, ax
		add bx, 2h
		and bx, 0feh	; mask of 11111110b to make di even
		add di, bx		; offset to video mem to align string


		pop ax			; get back colour
		push di
		@@Loop0_condition:		; Loop printing string until '$' symbol
		cmp byte ptr cs:[si], '$'
		je @@Loop0_skip

		lodsb
		stosw

		jmp @@Loop0_condition
		@@Loop0_skip:

		mov dx, es
		add dx, 0ah
		mov es, dx
		jmp @@Skip		;end No line break


		@@Line_break:

		mov ax, dx
		mov dx, 0h
		div bx			; (amount of full lines to write) = real length of string / aligned size of line
		mov cx, ax		; (amount of lines to write) - 1
		mov ax, bp
		sub ax, bx
		add ax, 4h
		and ax, 0feh	; mask of 11111110b to make di even
		dec bx
		add di, ax	; counting offset needed for di
		pop ax

@@Loop1:
		push di
		call Write_Line
		pop di
		mov dx, es
		add dx, 0ah
		mov es, dx
		loop @@Loop1

		push di
		@@Loop2_condition:		;printing remaining part of string
		cmp byte ptr cs:[si], '$'
		je @@Loop2_skip

		lodsb
		stosw
		jmp @@Loop2_condition
		mov dx, es
		add dx, 0ah
		mov es, dx
		@@Loop2_skip:
		@@Skip:
		pop di
		ret
		endp
;------------------------------------------------



;------------------------------------------------
; Prints 1 line
; Entry: SI - string offset, BX - aligned size of string
;	     AH - colour, DI - offset in video-mem segment,
; Exit:
; Destr: SI, DI
;------------------------------------------------
Write_Line	proc

		push cx
		mov cx, bx
WL_loop:
		lodsb
		stosw
		loop WL_loop

		pop cx
		ret
		endp
;------------------------------------------------



;------------------------------------------------
; Counts string's length
; Entry: DI - string offset
; Exit: CX - length
; Destr: AL, CX, DI
;------------------------------------------------

Str_Len		proc

		CLD
		mov cx, cs
		push es
		mov es, cx
		mov al, '$'
		mov cx, 0ffffh
		repne scasb
		neg cx
		dec cx
		pop es
		ret
		endp
;------------------------------------------------



;------------------------------------------------
; Atoi_dec
; Entry: DI - string with number offset
; Exit: AX - number
; Destr: AX, DI, BH
;------------------------------------------------

Atoi_dec	proc

		call Skip_spaces
		mov al, [di]
		sub al, '0'		; gets first symbol
		inc di
		@@cond:		; gets symbols until 'space'
		cmp byte ptr [di], ' '
		je @@skip_loop

		mov bh, DEC_BASE
		mul bh
		add al, [di]
		sub al, '0'
		inc di
		jmp @@cond

		@@skip_loop:
		ret
		endp
;------------------------------------------------

;------------------------------------------------
; Atoi_hex
; Entry: DI - string with number offset
; Exit: AX - number
; Destr: AX, DI, BH
;------------------------------------------------

Atoi_hex	proc

		call Skip_spaces
		mov ax, 0h
		mov al, [di]
		sub al, '0'		; gets first symbol
		inc di
		@@cond:
		cmp byte ptr [di], ' '
		je @@skip_loop

		cmp byte ptr [di], 'a'		; checks digit or letter

		shl ax, 4h		; mul 16 = HEX_BASE
		add al, [di]
		inc di

		jge @@let_2_cond

		sub al, '0'
		jmp @@cond

		@@let_2_cond:

		sub al, 'W'		; <=> sub ax, ('a' - 10d)
		jmp @@cond

		@@skip_loop:
		ret
		endp
;------------------------------------------------


;------------------------------------------------
; Itoa_hex
; Entry: SI - string with hex numbers, DI - result
;		 string
; Exit: None
; Destr: Al, BX, CX, DX, DI, BP
;------------------------------------------------

Itoa_hex	proc

		cli		; without this it didn't work properly
				; last registers were not written
		mov al, 9h		; |frequently compared values, faster if save in registers
		mov bp, 09fh	; | check whether it is a letter or digit
		mov bx, si		; avoiding save si

		@@cond:
		xor cx, cx
		cmp byte ptr cs:[di], ','
		jne @@Skip

		add di, REG_STR_OFFSET_2	; jmp to next memory for converted registers' values

		@@Skip:
		mov cl, byte ptr cs:[bx]
		cmp cl, '$'
		je @@Break

		cmp cx, bp		; check whether it is a letter or digit
		jg @@let_1_cond

		mov dx, cx		; if highest hex digit is digit
		shr dx, 4h		; remains only highest hex digit
		add dx, '0'
		shl dx, 8h		; shifting to its place in number
		jmp @@Check_2

		@@let_1_cond:

		mov dx, cx		; if highest hex digit is letter
		shr dx, 4h
		add dx, 'a' - 0ah
		shl dx, 8h

		@@Check_2:

		and cx, 00fh	; remains only lowest hex digit
		cmp cl, al		; check whether it is a letter or digit

		jg @@let_2_cond

		add dx, cx
		add dx, '0'
		inc bx
		mov ch, dl
		mov cl, dh
		mov cs:[di], cx		; puts into result string
		add di, 2h

		jmp @@cond

		@@let_2_cond:

		add dx, cx
		add dx, 'a' - 0ah
		inc bx
		mov ch, dl
		mov cl, dh
		mov cs:[di], cx
		add di, 2h

		jmp @@cond

		@@Break:
		sti
		ret
		endp
;------------------------------------------------

;------------------------------------------------
; Skips spaces
; Entry: DI - string to skip offset
; Exit: None
; Destr: AL, CX
;------------------------------------------------

Skip_spaces		proc

		mov cx, ds
		push es
		mov es, cx
		mov cx, 0ffffh
		mov al, ' '
		repe scasb
		sub di, 1h		; IDK why repe scasb does 1 extra iteration
		pop es
		ret
		endp
;------------------------------------------------

End_of_code:
end Start
