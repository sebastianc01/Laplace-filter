.DATA
imageHeight DD ?
imageWidth DD ?
noThreads DD ?
position DD ?
noRows DD ?
dataAddress DQ ?
modifiedDataAddress DQ ?
paddingSize DD ?


.CODE

laplaceAsm proc
; Address of the data is stored in RCX
; Address of the modified data is stored in RDX
; Padding size is stored in R8
; Image width is stored in R9
	mov rax, 5
;Saving data
	push rbp
    mov rbp, rsp
	mov dataAddress, rcx			;	Saving image data address
	mov modifiedDataAddress, rdx	;	Saving modified data address
	mov paddingSize, r8d			;   Saving padding size
	mov imageWidth, r9d				;	Saving image width
	mov eax, DWORD PTR [rbp+48]	
	mov imageHeight, eax			;	Saving image height
	mov eax, DWORD PTR [rbp+56]	
	mov noThreads, eax				;	Saving number of threads
	mov eax, DWORD PTR [rbp+64]
	mov position, eax				;	Saving position
	mov eax, DWORD PTR [rbp+72]
	mov noRows, eax					;	Saving number of rows to calculate in the thread
	push rax
	push rbx
	push r10
	push r11
	push r12						;
	push r13						;
	push r14						;
	push r15						;
;Saving data



;Set correct masks
	mov r8, 0001000100010001h
	movq xmm1, r8						
	mov r8, 0001000100010001h
	pinsrq xmm1, r8, 1
	mov r8, 0FFF7FFF7FFF7FFF7h
	movq xmm6, r8						
	mov r8, 0FFF7FFF7FFF7FFF7h
	pinsrq xmm6, r8, 1
;Set correct masks

; Important registers
; rbx - counter of columns (just to avoid calculating padding and image verges)
; rcx - counter of all elements
; r13 - number of bytes per single row
; r15 - first element beyond range predicted for this thread
; r10 - imageWidth - 1
; r8, r9 - used
; xmm1 - 1 in all shorts
; xmm6 - -8 in all shorts
; xmm2 - first row of the calculated array (with mask 1)
; xmm3 - second row of the calculated array (with mask -8)
; xmm5 - second row of the calculated array (with mask 1)
; xmm4 - third row of the calculated array (with mask 1)

	;Set registers
	mov r10d, imageWidth			; r10 contains image width
	sub r10, 1						; subtract 1 from r10, starts from 0 (to imageWidth - 1)
	xor rcx, rcx					; counter of all elements
	xor rax, rax					; set rax 0
	mov eax, imageWidth				; move image width to r13d
	mov r15, 3						
	mul r15							; multiply by 3, in result eax contains number of bytes per single row
	add eax, paddingSize			; add padding size to image width
	xor r15, r15					; set r15 to 0
	mov r13, rax					; r13 contains number of bytes per single row

	mul position					; rax already contains number of bytes per single row, now multiplied by position
	cmp rax, 0						; compare rax with 0
	jle	firstRow					; when less or equal then jump to firstRow (first row will be skipped)
	sub rax, r13					
	sub rax, r13					; subtract number of bytes per 2 rows from counter of all elements
	back0:
	mov rcx, rax					; rcx contains the first element to calculate in this thread
	xor rax, rax					; set rax to 0
	mov eax, position				; move position to eax
	add eax, noRows					; maximum row of the current thread is in rax
	mul r13							; first element beyond range predicted for this thread
	mov r15, rax					; r15 contains the first element beyond range predicted for this thread
	xor r9, r9

	startL:
	inc rbx							; increment the counter of the columns
	cmp rbx, r10					; compare counter of the columns with image width - 1
	je nextRow						; when equal, jump to nextRow
	add rcx, r13					; add number of bytes per single row to rcx
	add rcx, r13					; add number of bytes per single row to rcx
	cmp rcx, r15					; compare with first one beyond range predicted for this thread
	jge endL						; when it is greater or equal then jump to endL
	add rcx, dataAddress			; add data address to current element
	VPUNPCKLBW xmm4, xmm15, byte ptr [rcx]	; save data from the third row to xmm4 (16-bit integer)
	PSRLW xmm4, 8					; shift xmm4 8 bits right
	sub rcx, r13					; subtract number of bytes per single row
	VPUNPCKLBW xmm3, xmm15, byte ptr [rcx]	; save data from the second row to xmm3 (16-bit integer)
	PSRLW xmm3, 8					; shift xmm3 8 bits right
	vmovdqu xmm5, xmm3				; copy second row to xmm5
	sub rcx, r13					; subtract number of bytes per single row
	VPUNPCKLBW xmm2, xmm15, byte ptr [rcx]	; save data from the first row to xmm2 (16-bit integer)
	PSRLW xmm2, 8					; shift xmm2 8 bits right
	add rcx, r13					; rcx points middle row
	sub rcx, dataAddress
	add rcx, modifiedDataAddress
	vpmullw xmm4, xmm4, xmm1		; multiply xmm4 words by xmm1 words and save results in xmm4
	vpmullw xmm3, xmm3, xmm6		; multiply xmm3 words by xmm6 words and save results in xmm3
	vpmullw xmm2, xmm2, xmm1		; multiply xmm2 words by xmm1 words and save results in xmm2
	vpmullw xmm5, xmm5, xmm1		; multiply xmm5 words by xmm1 words and save results in xmm5
	vpaddw xmm2, xmm2, xmm5			; add dwords in xmm2 with dwords in xmm5 and save result in xmm2
	vpaddw xmm2, xmm2, xmm4			; add dwords in xmm2 with dwords in xmm4 and save result in xmm2
	xor r8, r8
	pextrw r8d, xmm2, 0				; store first word from xmm2 (sum of vertical results) in r8d
	pextrw eax, xmm2, 3				; store fourth word from xmm2 (sum of vertical results) in eax
	add r8d, eax
	pextrw eax, xmm2, 6				; store seventh word from xmm2 (sum of vertical results) in eax
	add r8d, eax
	pextrw eax, xmm3, 3				; store second word from xmm3 (center of the square with mask 8) in eax
	neg ax							; change sign
	sub r8d, eax					; subtract (add negative number)
	add rcx, 3						; add 3 to the current counter, now it points centre element
	mov r9b, r8b					; save contents of r8b in r9b
	xor r8b, r8b					; set r8b 0
	cmp r8, 0						; when r8 is equal to 0, then number is positive, negative otherwise
	jge positive1					; jump to positive1 when equal to 0
	mov r8b, r9b					; number is negative, return initial data
	neg r8b							; negate, change sign
	back1:
	mov byte ptr [rcx], r8b			; set first colour
	xor r8, r8
	xor r9, r9
	pextrw r8d, xmm2, 1				; store second word from xmm2 (sum of vertical results) in r8d
	pextrw eax, xmm2, 4				; store fifth word from xmm2 (sum of vertical results) in eax
	add r8d, eax
	pextrw eax, xmm2, 7				; store seventh word from xmm2 (sum of vertical results) in eax
	add r8d, eax
	pextrw eax, xmm3, 4				; store fifth word from xmm3 (center of the square with mask 8) in eax
	neg ax							; change sign
	sub r8d, eax					; subtract (add negative number)
	inc rcx							; increment, now it points second centre
	mov r9b, r8b					; save contents of r8b in r9b
	xor r8b, r8b					; set r8b 0
	cmp r8, 0						; when r8 is equal to 0, then number is positive, negative otherwise
	jge positive2					; jump to positive2 when equal to 0
	mov r8b, r9b					; number is negative, return initial data
	neg r8b							; negate, change sign
	back2:
	mov byte ptr [rcx], r8b			; set second colour
	sub rcx, modifiedDataAddress
	add rcx, dataAddress
	add rcx, 4						; add 4 to rcx, 1 to access next colour, 3 to access next column
	xor rax, rax
	xor r8, r8
	xor r9, r9
	mov al, byte ptr [rcx]			; move first element of the third row (third colour)
	add rcx, r13
	mov r8b, byte ptr [rcx]			; move second element of the third row (third colour)
	sub rcx, r13
	sub rcx, r13
	add r8, rax
	mov al, byte ptr [rcx]			; move third element of the third row (third colour)
	add r8, rax
	pextrw eax, xmm2, 2				; add third word from xmm2 (sum of vertical results) to r8d
	add r8d, eax
	pextrw eax, xmm2, 5				; add sixth word from xmm2 (sum of vertical results) to r8d
	add r8d, eax
	pextrw eax, xmm3, 5				; add fifth word from xmm2 (sum of vertical results) to r8d
	neg ax							; change sign
	sub r8d, eax					; subtract (add negative number)
	sub rcx, 3						; subtract 3 from rcx, now it points third centre element
	add rcx, r13					; add number of bytes per single row to rcx
	sub rcx, dataAddress
	add rcx, modifiedDataAddress
	mov r9b, r8b					; save contents of r8b in r9b
	xor r8b, r8b					; set r8b 0
	cmp r8, 0						; when r8 is equal to 0, then number is positive, negative otherwise
	jge positive3					; jump to positive3 when equal to 0
	mov r8b, r9b					; number is negative, return initial data
	neg r8b							; negate, change sign
	back3:
	mov byte ptr [rcx], r8b			; set third colour
	sub rcx, 2						; rcx points first centre element
	sub rcx, modifiedDataAddress
	sub rcx, r13
	jmp startL						; jump to startL

	firstRow:
	jmp back0

	positive1:
	mov r8b, r9b
	jmp back1

	positive2:
	mov r8b, r9b
	jmp back2

	positive3:
	mov r8b, r9b
	jmp back3

	nextRow:
	mov rbx, 0						; reset the column's counter
	add rcx, 6						; add 6 (first and last row pixels, both 3 colours) to counter of all elements
	xor rax, rax					; set rax to 0
	mov eax, paddingSize			; move padding size to eax
	add rcx, rax					; do not calculate padding and verge columns
	jmp startL						; jump to startL

	endL:
	pop r15
	pop r14
	pop r13
	pop r12
	pop r11
	pop r10
	pop rbx
	pop rax
	mov rsp, rbp
	pop rbp
	ret
laplaceAsm endp

TestAsm proc

;Save mask values in xmm1
	mov r8, 01010101010101h
	movq xmm2, r8						
	;mov r8, 0101010101010101h
	pinsrq xmm2, r8, 1	
	;movdqu xmm2, 0101010101010101h
	;mov al, 'G'
	;mov byte ptr [dataAddress + 656], al
	;pinsrb xmm3, byte ptr [dataAddress + 656], 2
	;mov al, 'J'
	;mov byte ptr [dataAddress + 656], al
	pinsrb xmm3, byte ptr [dataAddress + 656], 11
	pinsrb xmm3, byte ptr [dataAddress + 656], 1
	pinsrb xmm3, byte ptr [dataAddress + 656], 3
	pinsrb xmm3, byte ptr [dataAddress + 656], 4
	pinsrb xmm3, byte ptr [dataAddress + 656], 5
	pinsrb xmm3, byte ptr [dataAddress + 656], 6
	pinsrb xmm3, byte ptr [dataAddress + 656], 7
	pinsrb xmm3, byte ptr [dataAddress + 656], 8
	pinsrb xmm3, byte ptr [dataAddress + 656], 10
	pinsrb xmm3, byte ptr [dataAddress + 656], 9
	pinsrb xmm3, byte ptr [dataAddress + 656], 12
	pinsrb xmm3, byte ptr [dataAddress + 656], 13
	pinsrb xmm3, byte ptr [dataAddress + 656], 14
	pinsrb xmm3, byte ptr [dataAddress + 656], 15
	;pinsrb xmm3, byte ptr [dataAddress + 656], 0
	;pinsrb xmm3, byte ptr [dataAddress + 656], 16
	;pmaddubsw xmm2, xmm3

	;pextrb byte ptr [dataAddress], xmm3, 2
;Save mask values in xmm1
;Saving data
	push    rbp
    mov     rbp, rsp
	mov dataAddress, rcx
	mov modifiedDataAddress, rdx
	mov paddingSize, r8d
	mov imageWidth, r9d
	mov eax, DWORD PTR [rbp+48] ;	Image height is stored in eax
	mov imageHeight, eax
	mov eax, DWORD PTR [rbp+56] ;	Number of threads is stored in eax
	mov noThreads, eax
	mov eax, DWORD PTR [rbp+64] ;	Position is stored in eax
	mov position, eax
	mov eax, DWORD PTR [rbp+72] ; Number of rows is stored in eax
	mov noRows, eax
;Saving data
	;mov eax, DWORD PTR [dataAddress]	; move first element of the array to the eax
	;cvtsi2ss xmm0, eax					; convert 32-bit integer to 32-bit float
	;vbroadcastss xmm1, DWORD PTR [dataAddress]
	pop rbp
	ret
TestAsm endp

END