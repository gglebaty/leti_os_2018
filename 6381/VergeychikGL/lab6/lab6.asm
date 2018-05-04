.MODEL SMALL
;-----------------------------------------------------
CODE SEGMENT
	ASSUME CS:CODE, DS:DATA, ES:DATA, SS:ASTACK
;-----------------------------------------------------
START: 
	JMP BEGIN
;подготовка места и освобождение памяти 
Mem_proc PROC 
		lea bx,Last_byte 
		mov ax,es 
		sub bx,ax
		mov cl,4h
		shr bx,cl 

		mov ah,4Ah 
		int 21h
		jnc End_of_free_mem ;проверка CF

		cmp ax,7
		lea dx, Mem_error7
		je Error_mem_found
		cmp ax,8
		lea dx, Mem_error8
		je Error_mem_found
		cmp ax,9
		lea dx, Mem_error9
		
	Error_mem_found:
		call Write
		xor al,al
		mov ah,4Ch
		int 21H
	End_of_free_mem:
		ret
Mem_proc ENDP
;-----------------------------------------------------
;заполнение блока параметров
Param_block PROC
		mov ax, es
		mov Params,0
		mov Params+2, 80h
		mov Params+4, ax
		mov Params+6, 5Ch  
		mov Params+8, ax
		mov Params+10, 6Ch 
		mov Params+12, ax
		ret
Param_block ENDP
;-----------------------------------------------------
Call_LR2 PROC 
		;подготовка строки, содержащей путь и имя вызываемой программы
		lea dx, Path
		push ds
		pop es 
		lea bx, Params

		;сохранение содержимого регистров SS и SP в переменных
		mov Keep_sp, SP
		mov Keep_ss, SS
		
		;вызов загрузчика OS
		mov ax,4B00h
		int 21h
		jnc No_error 

		push ax
		mov ax,DATA
		mov ds,ax
		pop ax
		mov SS,Keep_ss
		mov SP,Keep_sp
		
		cmp ax,1
		lea dx, Error1
		je Error
		cmp ax,2
		lea dx, Error2
		je Error
		cmp ax,5
		lea dx, Error5
		je Error
		cmp ax,8 
		lea dx, Error8
		je Error
		cmp ax,10 
		lea dx, Error10
		je Error
		cmp ax,11 
		lea dx, Error11
		
	Error:
		call Write
		xor al,al
		mov ah,4Ch
		int 21h
			
	No_error:
		mov ax,4d00h
		int 21h
	
		cmp ah,0
		lea dx, End0
		je Exit
		cmp ah,1
		lea dx, End1
		je Exit
		cmp ah,2
		lea dx, End2
		je Exit
		cmp ah,3
		lea dx, End3

	Exit:
		call Write
		ret
Call_LR2 ENDP
;-----------------------------------------------------
Write PROC NEAR
		push ax
		mov ah, 09h
		int 21h
		pop ax
		ret
Write ENDP
;-----------------------------------------------------
BEGIN:
		mov ax,DATA
		mov ds, ax
		push ES
		mov ES, ES:[2CH]
		xor SI, SI
		lea DI, Path
	Skip: 
		inc SI      
		cmp WORD PTR ES:[SI], 0000H
		jne Skip
		add SI, 4       
	FileName:
		cmp BYTE PTR ES:[SI], 00H
		je EndFN
		mov DL, ES:[SI]
		mov [DI], DL
		inc SI
		inc DI
		jmp FileName   	
	EndFN:
		sub DI, 8
		mov [DI], 'rl'
		add DI, 2
		mov [DI], '.2'
		add DI, 2
		mov [DI], 'OC'
		add DI, 2
		mov BYTE PTR[DI], 'M'
		inc DI
		mov DL, '$'
		mov [DI], DL
		pop ES
		call Mem_proc 
		call Param_block
		call Call_LR2
		xor al,al
		mov ah,4Ch ;выход 
		int 21h
	Last_byte:
	CODE ENDS
;-----------------------------------------------------
ASTACK SEGMENT STACK
	DW 64 DUP (?)
ASTACK ENDS
;-----------------------------------------------------
;Данные
DATA SEGMENT
	Params dw ? ;сегментный адрес среды
	dd ? ;сегмент и смещение командной строки
	dd ? ;сегмент и смещение первого FCB
	dd ? ;сегмент и смещение второго FCB
	Mem_error7     DB 0DH, 0AH,'Error! MCB destroyed',0DH,0AH,'$'
	Mem_error8     DB 0DH, 0AH,'Error! Not enough memory',0DH,0AH,'$'
	Mem_error9     DB 0DH, 0AH,'Error! Wrong address',0DH,0AH,'$'
	Error1    DB 0DH, 0AH,'Error-1! Wrong number of function',0DH,0AH,'$'
	Error2    DB 0DH, 0AH,'Error-2! File not found',0DH,0AH,'$'
	Error5    DB 0DH, 0AH,'Error-5! Disk error',0DH,0AH,'$'
	Error8    DB 0DH, 0AH,'Error-8! Not enough memory',0DH,0AH,'$'
	Error10   DB 0DH, 0AH,'Error-10! Incorrect environment string',0DH,0AH,'$'
	Error11   DB 0DH, 0AH,'Error-11! Error with format',0DH,0AH,'$'
	End0    DB 0DH, 0AH,'Process finished successfully',0DH,0AH,'$'
	End1    DB 0DH, 0AH,'Ctrl-Break end!',0DH,0AH,'$'
	End2    DB 0DH, 0AH,'Device error end!',0DH,0AH,'$'
	End3    DB 0DH, 0AH,'Function 31h end!',0DH,0AH,'$'
	Path 	   DB 50 dup(0)
	Keep_ss    DW 0
	Keep_sp    DW 0
DATA ENDS
	END START