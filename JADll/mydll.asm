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
    mov     rbp, rsp
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
; r13 - number of bytes per single row
; r15 - first element beyond range predicted for this thread
; xmm1 - 1 in all shorts
; xmm6 - -8 in all shorts
; xmm2 - first row of the calculated array (with mask 1)
; xmm3 - second row of the calculated array (with mask -8)
; xmm5 - second row of the calculated array (with mask 1)
; xmm4 - third row of the calculated array (with mask 1)

;Trying to copy an image
	;Setting registers
	mov rbx, 0						; counter of all rows which have to be modificated in this thread
	xor rcx, rcx					; counter of all elements
	xor rax, rax					; set rax 0
	mov eax, imageWidth				; move image width to r13d
	add eax, paddingSize			; add padding size to image width
	mov r15, 3						
	mul r15							; multiply by 3, in result eax contains number of bytes per single row
	xor r15, r15					; set r15 to 0
	mov r13, rax					; r13 contains number of bytes per single row

	mul position					; rax already contains number of bytes per single row, now multiplied by position
	mov rcx, rax					; rcx contains the first element to calculate in this thread
	xor rax, rax
	mov eax, position
	add eax, noRows					; maximum row of the current thread is in rax
	mul r13							; first element beyond range predicted for this thread
	mov r15, rax					; r15 contains the first element beyond range predicted for this thread

	;test
;mov rax, dataAddress
;;add rax, r13
;mov byte ptr [rax], 12
;inc rax			 
;mov byte ptr [rax], 12
;inc rax			 
;mov byte ptr [rax], 12
;inc rax			 
;mov byte ptr [rax], 12
;inc rax			 
;mov byte ptr [rax], 11
;inc rax			 
;mov byte ptr [rax], 12
;inc rax			 
;mov byte ptr [rax], 11
;inc rax			 
;mov byte ptr [rax], 16
;inc rax			 
;mov byte ptr [rax], 11
;sub rax, 8
;add rax, r13
;mov byte ptr [rax], 22
;inc rax			 	
;mov byte ptr [rax], 22
;inc rax			 	
;mov byte ptr [rax], 22
;inc rax			 	
;mov byte ptr [rax], 22
;inc rax			 	
;mov byte ptr [rax], 21
;inc rax			 	
;mov byte ptr [rax], 22
;inc rax			 	
;mov byte ptr [rax], 21
;inc rax			 	
;mov byte ptr [rax], 26
;inc rax			 	
;mov byte ptr [rax], 21
;sub rax, 8
;add rax, r13
;mov byte ptr [rax], 32
;inc rax			 	
;mov byte ptr [rax], 32
;inc rax			 	
;mov byte ptr [rax], 32
;inc rax			 	
;mov byte ptr [rax], 32
;inc rax			 	
;mov byte ptr [rax], 31
;inc rax			 	
;mov byte ptr [rax], 32
;inc rax			 	
;mov byte ptr [rax], 31
;inc rax			 	
;mov byte ptr [rax], 36
;inc rax			 	
;mov byte ptr [rax], 31
;xor rax, rax
pxor xmm15, xmm15
;test

	startL:
	;sub rcx, r13					; subtract number of bytes per single row
	cmp rcx, r13					; compare with number of bytes per single row
	jl firstRow					; when less of equal to 0, then jump to firstRow
	add rcx, r13					; add previuosly substracted number of bytes per single row
	add rcx, r13					; add number of bytes per single row to rcx
	cmp rcx, r15					; compare with first one beyond range predicted for this thread
	jge endL						; when it is greater or equal then jump to endL
	add rcx, dataAddress			; add data address to current element
	VPUNPCKLBW xmm4, xmm15, byte ptr [rcx]	; save data from the third row to xmm4 (16-bit integer)
	PSRLW xmm4, 8
	sub rcx, r13					; subtract number of bytes per single row
	VPUNPCKLBW xmm3, xmm15, byte ptr [rcx]	; save data from the second row to xmm3 (16-bit integer)
	PSRLW xmm3, 8
	vmovdqu xmm5, xmm3				; copy second row to xmm5
	sub rcx, r13					; subtract number of bytes per single row
	VPUNPCKLBW xmm2, xmm15, byte ptr [rcx]	; save data from the first row to xmm2 (16-bit integer)
	PSRLW xmm2, 8
	add rcx, r13					; rcx points middle row
	sub rcx, dataAddress
	add rcx, modifiedDataAddress
	vpmullw xmm4, xmm4, xmm1
	vpmullw xmm3, xmm3, xmm6
	vpmullw xmm2, xmm2, xmm1
	vpmullw xmm5, xmm5, xmm1
	;pmullw xmm1, xmm2
	vpaddd xmm2, xmm2, xmm5
	vpaddd xmm2, xmm2, xmm4
	xor r8, r8
	;psllw xmm2, 4
	pextrw r8d, xmm2, 1				; store first dword from xmm2 (sum of vertical results) in r8d
	pextrw eax, xmm2, 4				; store fourth dword from xmm2 (sum of vertical results) in eax
	add r8d, eax
	pextrw eax, xmm2, 7				; store seventh dword from xmm2 (sum of vertical results) in eax
	add r8d, eax
	pextrw eax, xmm3, 2				; store second dword from xmm3 (center of the square with mask 8) in eax
	neg ax
	add r8d, eax
	add rcx, 3							; add 3 to the current counter, now it points centre element
	mov byte ptr [rcx], r8b				; set first colour
	;mov byte ptr [rcx], 200
	pextrw r8d, xmm2, 2				; store second dword from xmm2 (sum of vertical results) in r8d
	pextrw eax, xmm2, 5				; store fifth dword from xmm2 (sum of vertical results) in eax
	add r8d, eax
	pextrw eax, xmm2, 8				; store seventh dword from xmm2 (sum of vertical results) in eax
	add r8d, eax
	pextrw eax, xmm3, 5				; store fifth dword from xmm3 (center of the square with mask 8) in eax
	neg ax
	add r8d, eax
	inc rcx								; increment, now it points second centre
	mov byte ptr [rcx], r8b				; set second colour
	;mov byte ptr [rcx], 200
	add rcx, 4							; add 4 to rcx, 1 to access next colour, 3 to access next column
	xor rax, rax
	xor r9, r9
	mov al, byte ptr [rcx]
	add rcx, r13
	mov r9b, byte ptr [rcx]
	sub rcx, r13
	sub rcx, r13
	add r9, rax
	xor rax, rax
	mov r9b, byte ptr [rcx]
	add r9, rax
	pextrw r9d, xmm2, 3				; store third dword from xmm2 (sum of vertical results) in r8d
	add r8d, eax
	pextrw r8d, xmm2, 6				; store sixth dword from xmm2 (sum of vertical results) in r8d
	add r8d, eax
	pextrw r8d, xmm3, 7				; store seventh dword from xmm2 (sum of vertical results) in r8d
	neg ax
	add r8d, eax
	sub rcx, 3						; subtract 3 from rcx, now it points centre element
	add rcx, r13						; add number of bytes per single row to rcx
	mov byte ptr [rcx], r8b			; set third colour
	;mov byte ptr [rcx], 200
	;;inc rcx
	sub rcx, modifiedDataAddress
	sub rcx, r13
	jmp startL						; jump to startL

	jmp endL
	firstRow:
	add rcx, r13
	jmp startL

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