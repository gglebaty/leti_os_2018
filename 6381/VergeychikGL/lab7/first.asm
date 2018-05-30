OVL_SEG SEGMENT
	ASSUME CS:OVL_SEG, DS:nothing, SS:nothing, ES:nothing
	
MAIN PROC FAR
	PUSH DS
	PUSH AX
	PUSH DI
	PUSH DX
	
	MOV AX, CS
	MOV DS, AX
	
	LEA DI, SEG_ADR
	ADD DI, 23								
	CALL WRD_TO_HEX
	
	LEA DX, SEG_ADR
	MOV AH, 09H
	INT 21H

	POP DX
	POP DI
	POP AX
	POP DS
	RETF
MAIN ENDP

SEG_ADR 	db 	0DH, 0AH,'Сегментный адрес:     ', 0DH, 0AH,0DH,0AH, '$'

TETR_TO_HEX PROC
	and AL,0Fh 
	cmp AL,09 
	jbe NEXT 
	add AL,07 
NEXT: 
	add AL,30h 
	ret 
TETR_TO_HEX ENDP 

BYTE_TO_HEX PROC 

	push CX 
	mov AH,AL 
	call TETR_TO_HEX 
	xchg AL,AH 
	mov CL,4 
	shr AL,CL 
	call TETR_TO_HEX 
	pop CX 
	ret 
BYTE_TO_HEX ENDP 

WRD_TO_HEX PROC  
	push BX 
	mov BH,AH 
	call BYTE_TO_HEX 
	mov [DI],AH 
	dec DI 
	mov [DI],AL 
	dec DI 
	mov AL,BH 
	call BYTE_TO_HEX 
	mov [DI],AH 
	dec DI 
	mov [DI],AL 
	pop BX 
	ret 
WRD_TO_HEX ENDP 

OVL_SEG ENDS
	END 