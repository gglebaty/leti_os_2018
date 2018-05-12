ASSUME CS:CODE, DS:DATA, SS:SSTACK
;-------------------------------------------------------------

;-------------------------------------------------------------

;-------------------------------------------------------------
CODE SEGMENT

;-----------------------------------------------------
;Прерывание
ROUT proc far
jmp no_data

	AD_PSP dw ?		;3 байта
	SR_PSP dw ?		;5 байт
	KEEP_CS dw ?	;7 байт
	KEEP_ID dw ?	;9 байт
	ID dw 0AAAAh	;11 байт
	ADR dw 0506h   

	scan_code db 2h, 3h, 4h, 5h, 6h, 7h, 8h, 9h, 0Ah, 0Bh, 82h, 83h, 84h, 85h, 86h, 87h, 88h, 89h, 8Ah, 8Bh, 00h
	KEEP_SS dw ?
	KEEP_SP dw ?
	NEWTABLE db '  abcdefghij'
no_data:
mov KEEP_SS,ss
mov KEEP_SP,sp

mov di, cs
mov ss, di
mov sp, offset STACK_END

	;Сохранение изменяемых регистров
	push ax
	;Считывание номера клавиши
	
	mov ah,02h
    int 16h
    test  al, 2;сравниваем со скан кодом Shift
    jne end_compare

	in al, 60h
	;Проверка на требуемые скан-коды
	
	push ds
	push ax
	mov ax, SEG scan_code
	mov ds, ax
	pop ax
	mov dx, offset scan_code
	;dx - смещение символов, al - сам символ
	push bx
	push cx
	mov bx, dx
	sub ah, ah
	;Сравнение кодов
for_compare:
	mov cl, byte ptr [bx]
	cmp cl, 0h
	je end_compare
	cmp al, cl
	jne no_equally
	;Совпадает
	mov ah, 01h
no_equally:
	;Не совпадает
	inc bx
	jmp for_compare
end_compare:
	pop cx
	pop bx
	pop ds
	
	cmp ah, 01h
	je processing
	jmp not_processing

not_processing:
	;Возврат к стандартному обработчику прерывания
	pop ax
	mov ss, KEEP_SS
	mov sp, KEEP_SP
	pushf
	push KEEP_CS
	push KEEP_ID
	iret
processing:
	;Обработка прерывания
	push bx
	push cx
	push dx
	
	cmp al,80h
	ja go
	
	push es
	push ds
	push ax
	
	mov ax, seg NEWTABLE
	mov ds, ax
	mov bx, offset NEWTABLE
	pop ax	

	xlatb
	pop ds
write_to_buffer:
	;Запись в буфер клавиатуры
	mov ah, 05h
	mov cl, al
	sub ch, ch
	int 16h
	or al, al
	jnz cleaning
	pop es
go:
	jmp @ret
	;Очистка буфера и повторение
cleaning:
	push ax
	mov ax, 40h
	mov es, ax
	mov word ptr es:[1Ah], 001Eh
	mov word ptr es:[1Ch], 001Eh
	pop ax
jmp write_to_buffer
	@ret:
	;Отработка аппаратного прерывания
	in al, 61h
	mov ah, al
	or al, 80h
	out 61h, al
	xchg ah, al
	out 61h, al
	mov al, 20h
	out 20h, al	
	
	;Востановление регистров
	pop dx
	pop cx
	pop bx
	
	pop ax
	
	mov ss, KEEP_SS
	mov sp, KEEP_SP
	
	iret
ROUT endp

;tsr_end:

	NEW_STACK dw 64 dup(?)		; стек
	STACK_END:
	
	TEMP:
	
	
;ORG tsr_end

;-----------------------------------------------------
; КОД
BEGIN PROC FAR
	mov bx,02Ch
	mov ax,[bx]
	mov SR_PSP,ax
	mov AD_PSP,ds
	sub ax,ax    
	xor bx,bx
	
	mov ax, DATA
	mov ds, ax
;Проверка на загрузку резидента в память
	push es
	mov ah, 35h
	mov al, 09h
	int 21h
	mov dx, es:[bx+11]
	pop es
	cmp dx, ID
	jne no_load
	;Резидент загружен
	mov isLoad, 1
	jmp load
no_load:
	;Резидент не загружен
	mov isLoad, 0
load:

;Проверка на выгрузку резидента из памяти
	push es
	push ax
	mov ax, es
	mov es, ax
	mov cl, es:[80h]
	mov dl, cl
	sub ch, ch
	test cl, cl	
	jz no_unload
	;Проверка ключа
	mov al, es:[82h]
	cmp al, '/'
	jne no_unload
	
	mov al, es:[83h]
	cmp al, 'u'
	jne no_unload
	
	mov al, es:[84h]
	cmp al, 'n'
	jne no_unload
	
	mov isUnload, 1
	jmp unload
no_unload:
	mov isUnload, 0
unload:
	pop ax
	pop es
	

	cmp isLoad, 1
	je already_load
	cmp isUnload,0
	je nextStep
	lea dx,resAlready
	mov ah,09h
	int 21h
	jmp exit
	nextStep:
	
;Если резидент не загружен, то загрузим его
	; Загрузка обработчика прерывания
	mov ah, 35h
	mov al, 09h
	int 21h
	mov KEEP_CS, es
	mov KEEP_ID, bx
	;Установка прерывания
	push ds
	mov dx, offset ROUT ;Смещение функции
	mov ax, seg ROUT ;Сегмент функции
	mov ds, ax
	mov ah, 25h ;Номер функции установки вектора
	mov al, 09h ;Номер вектора
	int 21h
	pop ds
	;Вывод сообщения о установке прерывания
	lea dx, resLoad
	mov     ah, 09h 
    int     21h 
	;Оставление резидентной функции в памяти
	mov dx, offset TEMP
	mov cl, 4
	shr dx, cl
	add dx, 9h;
	mov ah, 31h
	int 21h
already_load:
;Если резидент уже был загружен
	cmp isUnload, 1
	je unload_int
; Не надо выгружать прерывание
	lea dx, resAlready
	mov     ah, 09h 
    int     21h 
	jmp exit
unload_int:
;Необходимо выгрузить прерывание
	mov ax, 3509h ; функция получения вектора
	int  21H
	;Выгрузка обработчика прерывания
	cli
	push ds
	mov dx,es:[bx+9]   ;IP стандартного прерывания
	mov ax,es:[bx+7]   ;CS стандартного прерывания
	mov ds, ax
	mov ah, 25h
	mov al, 09h
	int 21h
	pop ds
	sti
	;Вывод сообщения о выгрузке прерывания
	lea dx, resUnload
	mov     ah, 09h 
    int     21h 
	
	;Очистка памяти из под прерывания
	push es
	mov cx,es:[bx+3]
	mov es,cx
	mov ah,49h
	int 21h
	
	pop es
	mov cx,es:[bx+5]
	mov es,cx
	int 21h
	
exit:
; Выход в DOS
	mov ah, 4ch
	int 21h

BEGIN ENDP
;------------------------------------------------------------------
CODE ENDS
;------------------------------------------------------------------
DATA SEGMENT
;ДАННЫЕ
	resLoad      db  'Resident loaded!', 0DH, 0AH, '$'
	resUnload      db  'Resident unloaded!', 0DH, 0AH, '$'
	resAlready      db  'already executed!', 0DH, 0AH, '$'
	isLoad db 0
	isUnload db 0
DATA ENDS
SSTACK SEGMENT STACK 
	DW 64 DUP(?)
SSTACK ENDS
END BEGIN