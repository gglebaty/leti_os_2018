TESTPC	SEGMENT
		ASSUME	CS:TESTPC,	DS:TESTPC,	ES:NOTHING,	SS:NOTHING
		ORG		100H
START:	JMP		BEGIN

; ДАННЫЕ
ADD_N			db		'Address not available memory:     ',0dh,0ah,'$'
ASP_N			db		'Address of environment:     ',0dh,0ah,'$'
TAIL			db		'Commandline tail:','$'
SOD_SRED		db		'Environment scope content: ' , '$'
PATH			db		'Path to module: ' , '$'
ENDL			db		0dh,0ah,'$'

NEW_LINE		PROC	near
		lea		dx,ENDL
		call	Write_msg
		ret
NEW_LINE		ENDP

Write_msg		PROC	near
		mov		ah,09h
		int		21h
		ret
Write_msg		ENDP

TETR_TO_HEX		PROC	near
		and		al,0fh
		cmp		al,09
		jbe		NEXT
		add		al,07
NEXT:	add		al,30h
		ret
TETR_TO_HEX		ENDP
;---------------------------
BYTE_TO_HEX		PROC near
; байт в AL переводится в два символа шестн. числа в AX
		push	cx
		mov		ah,al
		call	TETR_TO_HEX
		xchg	al,ah
		mov		cl,4
		shr		al,cl
		call	TETR_TO_HEX ; 
		pop		cx 			
		ret
BYTE_TO_HEX		ENDP
;--------------------------
WRD_TO_HEX		PROC	near
; первод в 16 с/с 16-ти разрядного числа
; в AX - число, DI - адрес последнего символа
		push	bx
		mov		bh,ah
		call	BYTE_TO_HEX
		mov		[di],ah
		dec		di
		mov		[di],al
		dec		di
		mov		al,bh
		call	BYTE_TO_HEX
		mov		[di],ah
		dec		di
		mov		[di],al
		pop		bx
		ret
WRD_TO_HEX		ENDP
;----------------------------
; Определяем первый байт недоступной памяти
GET_INACCESSIBLE_MEM 	PROC	near
		push	ax
		mov 	ax,es:[2]
		lea		di,ADD_N
		add 	di,33
		call	WRD_TO_HEX
		pop		ax
		ret
GET_INACCESSIBLE_MEM 		ENDP
;----------------------------
; Определяем сегментный адрес среды передаваемой программе
GET_SEGMENT_ADRESS 		PROC	near
		push	ax
		mov 	ax,es:[2Ch]
		lea		di,ASP_N
		add 	di,27
		call	WRD_TO_HEX
		pop		ax
		ret
GET_SEGMENT_ADRESS 		ENDP
;----------------------------
; Определяем хвост командной строки в символьном виде
GET_COMMANDLINE_TAIL 		PROC	near
	push	ax
		push	cx
    	xor 	ax, ax
    	mov 	al, es:[80h]
    	add 	al, 81h
    	mov 	si, ax
    	push 	es:[si]
    	mov 	byte ptr es:[si+1], '$'
    	push 	ds
    	mov 	cx, es
    	mov 	ds, cx
    	mov 	dx, 81h
    	call	Write_msg
   	 	pop 	ds
    	pop 	es:[si]
    	pop		cx
    	pop		ax
		ret
GET_COMMANDLINE_TAIL 		ENDP
;----------------------------
; Определяем содержимое области среды и путь к модулю
GET_CONTENT_AND_PATH 	PROC	near
		push 	es ; Сохраняем
		push	ax ; изменяемые
		push	bx ; данные
		push	cx ; в стеке.
		mov		bx,1 ; Задаем проверочному регистру, на условие вывода Пути до модуля, значение 1
		mov		es,es:[2ch] ; Заносим в es начало содержимого области среды
		mov		si,0 ; Вспомогательному регистру задаем значение 0
	RE1:
		call	NEW_LINE ; Перенос на новую строчку
		mov		ax,si ; Сохраняем адрес начала имени элемента области среды
	RE:
		cmp 	byte ptr es:[si], 0 ; Проверяем не 0 ли этот элемент
		je 		NEXT2 ; Как только доходим до конца элемента области среди переходим к метке NEXT2
		inc		si ; Увеличиваем si на 1
		jmp 	RE ; Прыгаем к метке RE
	NEXT2:
		push	es:[si] ; Сохраняем значение текущей ячейки в стек
		mov		byte ptr es:[si], '$' ; Присваиваем этой ячейке знак окончания строки
		push	ds ; Сохраняем занчение регистра ds в стек
		mov		cx,es ; Заносим в регистр cx значение регистра es
		mov		ds,cx ; Задаем регистру ds значение регистра cx
		mov		dx,ax ; Заносим в регистр dx занчение адрес начала строки
		call	Write_msg ; Выводим текущую строчку на экран
		pop		ds ; Возвращаем значение ds
		pop		es:[si] ; Возвращаем значение текущей ячейки
		cmp		bx,0 ; Проверка условия о выводе пути до модуля
		jz 		LAST ; Если bx = 0 то переходим к концу процедуры
		inc		si ; Увеличиваем si на 1
		cmp 	byte ptr es:[si], 01h ; Проверка на то, идет ли дальше информация о пути до модуля
    	jne 	RE1 ; Возвращаемся к метке RE1
   ;	call	NEW_LINE ; Перенос строки
    	lea		dx,PATH ; Заносим занчение переменной PATH в dx
    	call	Write_msg ; Выводим сообщение на экран
    	mov		bx,0 ; Меняем переменную bx на ноль, решая тем самым, что дальше идет адрес пути до модуля
    	add 	si,2 ; Пропускаем не нужные символы
    	jmp 	RE1 ; Прыгаем к метке RE1
    LAST:
    	;	call	NEW_LINE ; Перенос строки
		pop		cx ; Возвращаем
		pop		bx ; данные
		pop		ax ; из 
		pop		es ; стека.
		ret
GET_CONTENT_AND_PATH 	ENDP
;----------------------------
Write		PROC	near
		mov		ah,09h
		int		21h
		ret
Write		ENDP
BEGIN:
		call	GET_INACCESSIBLE_MEM  ;Определяем первый байт недоступной памяти
		call	GET_SEGMENT_ADRESS  ;и сегментый адрес передаваемой строки
		lea		dx,ADD_N   
		call	Write_msg  ;Выводим 
	;	call	NEW_LINE   ;на экран
		lea		dx,ASP_N   ;эти
		call	Write_msg  ;данные ;		call	NEW_LINE 
		lea 	dx, TAIL   
    		call 	Write_msg  ;Выводим слово "Tail:"
    		call	GET_COMMANDLINE_TAIL  ;Определяем и выводим хвост командной строки в символьном виде
    		call	NEW_LINE 
		lea		dx,SOD_SRED 
		call	Write_msg   ;Выводим строку Content of the environment:"
		call	GET_CONTENT_AND_PATH  ;Определяем и выводим содержимое области среды и путь к модулю
		
		; выход в DOS
		xor	al,al
		mov 	ah, 01h
		int	21h
		mov 	ah, 04Ch
		int 	21h
		ret
TESTPC	ENDS
		END 	START