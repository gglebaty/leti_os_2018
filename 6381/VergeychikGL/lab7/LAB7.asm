DATA SEGMENT
	PREFIX 		DB 'Путь к файлу: $'
	FILENAME 	DB 64 DUP(0)

	OVL_1 		DB 'first',0
	OVL_2 		DB 'second',0
	
	DTA_BLOCK 	DB 43 DUP(0) ;буфер для заполнения при поиске файла

	OVL_SEGMENT DW 0
	OVL_ADRESS 	DD 0 ;дальний адрес оверлея
	
	KEEP_PSP 	DW 0
	
;Сообщения об ошибках при поиске файла
	ERR_FIND_NUM_2  	DB 0DH, 0AH,'Файл не найден!',0DH,0AH,'$'
	ERR_FIND_NUM_3   	DB 0DH, 0AH,'Маршрут не найден!',0DH,0AH,'$'
	
;Сообщения об ошибках запуска программы
	ERR_CALL_NUM_1    	DB 0DH, 0AH,'Неверный номер функции!',0DH,0AH,'$'
	ERR_CALL_NUM_2    	DB 0DH, 0AH,'Файл не найден!',0DH,0AH,'$'
	ERR_CALL_NUM_5    	DB 0DH, 0AH,'Ошибка диска!',0DH,0AH,'$'
	ERR_CALL_NUM_8    	DB 0DH, 0AH,'Недостаточный объем памяти!',0DH,0AH,'$'
	ERR_CALL_NUM_10   	DB 0DH, 0AH,'Неправильная строка среды!',0DH,0AH,'$'
	
;Сообщение об ошибке при выделении памяти
	ERR_MEM_AL 			DB 'Ошибка при выделении памяти!',0DH,0AH,'$'
	
DATA ENDS

ASTACK SEGMENT STACK
	DW 64 DUP (0)
ASTACK ENDS

CODE SEGMENT
ASSUME CS:CODE, DS:DATA, ES:DATA, SS:ASTACK

;Процедура для вывода сообщения
WRITE PROC 
		PUSH AX
		MOV AH, 09H
		INT 21H
		POP AX
		RET
WRITE ENDP

;установка адреса DTA_BLOCK
SET_DTA_BLOCK PROC
		PUSH DX
		LEA DX, DTA_BLOCK
		MOV AH,1AH 
		INT 21H 
		POP DX
SET_DTA_BLOCK ENDP

;Процедура для освобождения лишней памяти
CUT_MEM PROC
	LEA BX, END_OF_THIS_PROGRAMM
	MOV AX, ES
	SUB BX, AX
	MOV CL, 4
	SHR BX, CL
	MOV AH, 4AH 
	INT 21H
	JNC NOT_MEMORY_ERROR
	
	LEA DX, ERR_MEM_AL
	CALL WRITE	
	MOV AH, 4CH
	INT 21H
NOT_MEMORY_ERROR:
	RET
CUT_MEM ENDP

;функция для определения имени запускаемой программы
;в BX необходимо переместить смещения строки с именем файла
GET_FILE_NAME PROC
		PUSH ES
		MOV ES, ES:[2CH]
		XOR SI, SI
		LEA DI, FILENAME
		
SKIP_ENV_PART: 
		INC SI      
		CMP WORD PTR ES:[SI], 0000H
		JNE SKIP_ENV_PART
		ADD SI, 4     
		
PATH_SYMBOL:
		CMP BYTE PTR ES:[SI], 00H
		JE END_FILE_NAME
		MOV DL, ES:[SI]
		MOV [DI], DL
		INC SI
		INC DI
		JMP PATH_SYMBOL  
		
END_FILE_NAME: ;поиск последней директории
		DEC SI
		DEC DI
		CMP BYTE PTR ES:[SI], '\'
		JNE END_FILE_NAME

		INC DI
		MOV SI, BX ;Загрузка из регистра строки
		PUSH DS
		POP ES
		
SIMP_OVL: ;заполнение имени файла
		LODSB
		STOSB
		CMP AL, 0
		JNE SIMP_OVL
		
		MOV BYTE PTR [DI], '$'
		
		LEA DX, PREFIX
		CALL WRITE
		
		LEA DX, FILENAME
		CALL WRITE
		
		POP ES
		RET
GET_FILE_NAME ENDP

;Выделение памяти  для оверлея
GET_MEM_FOR_OVL PROC
		PUSH DS
		PUSH DX
		PUSH CX
		XOR CX, CX
		
		LEA DX, FILENAME
		MOV AH,4EH ;поиск файла 
		INT 21H
		JNC FILE_FOUNDED

		CMP AX,3
		LEA DX, ERR_FIND_NUM_3
		JE ERROR_FIND_EXIT
		LEA DX, ERR_FIND_NUM_2

ERROR_FIND_EXIT: ;выход при обнаружении ошибки
		CALL WRITE
		POP CX
		POP DX
		POP DS
		XOR AL,AL
		MOV AH,4CH
		INT 21H
		
FILE_FOUNDED: ;файл найден
		PUSH ES
		PUSH BX
		LEA BX, DTA_BLOCK
		MOV DX,[BX+1CH]
		MOV AX,[BX+1AH]
		MOV CL,4H
		SHR AX,CL
		MOV CL,12 
		SAL DX, CL 
		ADD AX, DX 
		INC AX
		MOV BX,AX 
		
		MOV AH,48H 
		INT 21H 
		JC ERR_EXIT
		
		MOV OVL_SEGMENT, AX
		
		POP BX
		POP ES
		POP CX
		POP DX
		POP DS
		RET

ERR_EXIT:
		LEA DX, ERR_MEM_AL
		CALL WRITE	
		MOV AH, 4CH
		INT 21H
GET_MEM_FOR_OVL ENDP

;Вызов оверлея
CALL_OVL PROC 
		PUSH DX
		PUSH BX
		PUSH AX
		
		MOV BX, SEG OVL_SEGMENT
		MOV ES, BX
		LEA BX, OVL_SEGMENT

		LEA DX, FILENAME
		
		MOV AX, 4B03H
		INT 21H
		
		JNC NO_ERROR_IN_CALL
		
		CALL WHAT_ERROR_IN_CALL
		JMP EX_FROM_CALL

NO_ERROR_IN_CALL:
		MOV AX,DATA 
		MOV DS,AX
		MOV AX, OVL_SEGMENT
		MOV WORD PTR OVL_ADRESS+2, AX
		CALL OVL_ADRESS
		MOV AX, OVL_SEGMENT
		MOV ES, AX
		MOV AX, 4900H
		INT 21H
		MOV AX,DATA 
		MOV DS,AX
		
EX_FROM_CALL:
		MOV ES, KEEP_PSP
		POP AX
		POP BX
		POP DX
		RET
CALL_OVL ENDP

;Процедура для определения ошибки, если программа не запустилась
WHAT_ERROR_IN_CALL PROC
		CMP AX,1
		LEA DX, ERR_CALL_NUM_1
		JE WRITE_ERR
		CMP AX,2
		LEA DX, ERR_CALL_NUM_2
		JE WRITE_ERR	
		CMP AX,5
		LEA DX, ERR_CALL_NUM_5
		JE WRITE_ERR
		CMP AX,8 
		LEA DX, ERR_CALL_NUM_8
		JE WRITE_ERR
		CMP AX,10 
		LEA DX, ERR_CALL_NUM_10
WRITE_ERR:		
		CALL WRITE
		ret
WHAT_ERROR_IN_CALL ENDP

BEGIN PROC FAR
		mov ax, DATA
		mov ds, ax	
		mov Keep_psp, ES
		
		CALL CUT_MEM
		CALL SET_DTA_BLOCK
		
		LEA BX, OVL_1
		CALL GET_FILE_NAME ;
		CALL GET_MEM_FOR_OVL
		CALL CALL_OVL
		
		LEA BX, OVL_2
		CALL GET_FILE_NAME 
		CALL GET_MEM_FOR_OVL
		CALL CALL_OVL

		MOV AH, 4CH
		INT 21H
		
END_OF_THIS_PROGRAMM:		
BEGIN ENDP

CODE ENDS

	END BEGIN
