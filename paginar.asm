section .data

;///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	;ESTA PORCION DE CODIGO SIRVE PARA DETENER EL MODO CANONICO DE LA CONSOLA
	;FUE EXTRAIDO DEL SIGUIENTE LINK DE LA PAGINA STACKOVERFLOW.COM
	;http://stackoverflow.com/questions/3305005/how-do-i-read-single-character-input-from-keyboard-using-nasm-assembly-under-u
	
	termios:        times 36 db 0
	stdin:          equ 0
	ICANON:         equ 1<<1
	ECHO:           equ 1<<3
	
	canonical_off:
	        call read_stdin_termios
	
	        ; clear canonical bit in local mode flags
	        push eax
	        mov eax, ICANON
	        not eax
	        and [termios+12], eax
	        pop eax
	
	        call write_stdin_termios
	        ret
	
	echo_off:
	        call read_stdin_termios
	
	        ; clear echo bit in local mode flags
	        push eax
	        mov eax, ECHO
	        not eax
	        and [termios+12], eax
	        pop eax
	
	        call write_stdin_termios
	        ret
	
	canonical_on:
	        call read_stdin_termios
	
	        ; set canonical bit in local mode flags
	        or dword [termios+12], ICANON
	
	        call write_stdin_termios
	        ret
	
	echo_on:
	        call read_stdin_termios
	
	        ; set echo bit in local mode flags
	        or dword [termios+12], ECHO
	
	        call write_stdin_termios
	        ret
	
	read_stdin_termios:
	        push eax
	        push ebx
	        push ecx
	        push edx
	
	        mov eax, 36h
	        mov ebx, stdin
	        mov ecx, 5401h
	        mov edx, termios
	        int 80h
	
	        pop edx
	        pop ecx
	        pop ebx
	        pop eax
	        ret
	
	write_stdin_termios:
	        push eax
	        push ebx
	        push ecx
	        push edx
	
	        mov eax, 36h
	        mov ebx, stdin
	        mov ecx, 5402h
	        mov edx, termios
	        int 80h
	
	        pop edx
	        pop ecx
	        pop ebx
	        pop eax
	        ret

	;AQUI TERMINA LA PORCION DE CODIGO EXTRAIDA DE STACKOVERFLOW.COM
;/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	;texto Linea
	txt_linea db ' Lineas leidas.',10
	len_linea equ $ - txt_linea	

	;texto de errores
	err01 db 'Error en el archivo de entrada.',10
	len_err01 equ $ - err01
	
	err02 db 'Error en los parametros.',10
	len_err02 equ $ - err02
	
	err03 db 'Error desconocido.',10
	len_err03 equ $ - err03

	;ayuda
	txt_help db 'Uso: enum [-h] [ archivo_entrada | archivo_entrada archivo_salida]',10
	len_help equ $ - txt_help
		
	;variables auxiliares
	tmp_lineas dd 0	
	cont dd 0				;contador de lineas leidas en total
	cParcial dd 0				;contador de lineas leidas parcialmente,
						;para leer 20 o n lineas

section .bss
	buffer resb 1				;guarda los caracteres leidos del archivo
	lineas resd 1				;cantidad de lineas a leer
	fd_input resd 1

section .text
	global _start

_start:
	main:
		pop eax				;desapilo ARGC
		pop ebx				;desapilo ARGV[0]
		cmp eax,1
		jz _show_err02 			;muestra un mensaje de error por parametros
		cmp eax,2			;comparo el parametro que se paso	
		jz _un_parametro						
		cmp eax,3			;comparo el 1er parametro con "-nXX" o "-h"
		jz _dos_parametros		;si es "-nXX" compagino el archivo cada ¨n¨ lineas
						;si es "-h" muestro la ayuda por pantalla
		call _show_err02		;sino muestro que hubo un error en los parametros

;_un_parametro
;Verifica si el unico parametro que se paso es un "-h" o una ruta
	_un_parametro:
		pop ebx 			;obtenemos el ARGV[1] 
		call es_h			;verifica si es -h
		cmp eax,0			;comparamos el resultado de es_h
		jz _show_help			;si es_h setea a eax en 0, imprimimos el mensaje de ayuda
		jmp _paginar_20			;en caso contrario, es una ruta. Paginamos con 20 lineas

;_dos_parametros
;Verifica si el primer parametro es un "-h" o "-nXX" y si la ruta es valida
	_dos_parametros:
		pop ebx 			;obtenemos el ARGV[1]
		call es_h			;verificamos si el primer parametro es "-h".
		cmp eax,0			;comparamos el resultado de es_h
		jz _show_help			;si es_h setea a eax en 0, imprimimos el mensaje de ayuda
		call es_nXX			;en caso contrario, controlamos si el primer parametro es "-nXX".
		cmp eax,0			;comparamos el resultado de es_nXX	
		jz _paginar_n			;si es_nXX setea a eax en 0, entonces se compagina con "n" lineas
		jmp _show_err02			;si llega a aca, muetra un que hubo un error en los parametros.

;_paginar_n
;Muestra el contenido del archivo paginando segun el numero pasado por parametro
	_paginar_n:
		xor eax,eax				
		mov al,[ebx+2]			;recuperamos el primer digito del numero de lineas pasado por parametro 
		sub al,48			;le restamos su codigo ascii para obtener el valor real
		mov edx,10			
		mul edx				;lo multiplicamos por 10
		mov edx,eax			
		xor eax,eax 			
		mov al,[ebx+3]			;recuperamos el segundo digito del numero de lineas pasado por parametro
		sub al,48			;le restamos su codigo ascii para obtener el valor real
		add eax,edx			;sumamos los dos digitos para obtener el numero de lineas pasado por parametro
		dec eax 			;se le resta la linea donde se muestra la cantidad de lineas leidas
		mov [lineas],eax		;guardamos el numero obtenido en "lineas"				
		mov [tmp_lineas],eax		
		cmp eax,1			;comparamos si el numero de lineas es mayor a 2 
		jl _show_err02			;si no lo es, lanzamos un mensaje de error por parametros invalidos
		pop ebx				;obtenemos el puntero a la ruta del archivo
		call _open_file			;abrimos el archivo de entrada
		mov [fd_input],eax		;guardamos el file descriptor del archivo en "fd_input"
		jmp _procesar_lineas		;procesamos las lineas del archivo de entrada

;_paginar_20
;Muestra el contenido del archivo considerando una consola de 20 lineas
	_paginar_20:
		mov eax, 19			;indicamos que queremos procesar 20 lineas antes 
						;de llamar a procesar_lineas (19 lineas del archivo + linea "cantidad")
		mov [lineas],eax		;guardamos el numero de lineas a procesar en "lineas"
		mov [tmp_lineas],eax
		call _open_file			;abrimos el archivo de entrada
		mov [fd_input],eax		;guardamos el file descriptor del archivo en "fd_input"
		jmp _procesar_lineas		;procesamos las lineas del archivo

;_procesar_lineas
;Procesa n lineas de un archivo, recibe en ebx el file descriptor del archivo
;y en la variable "lineas", el numero de lineas a procesar	
	_procesar_lineas:
		mov eax,[tmp_lineas]
		mov [lineas],eax
		call _read_char			;leemos un caracter
		cmp eax,0			;preguntamos si se termino de leer todo el archivo
		jz _eof				;si es asi, salta a fin de archivo
		call _print_char		;imprimimos el caracter leido
		mov al,[buffer]	
		mov cl,10		
		cmp al,cl			;comparamos el caracter leido con el caracter de salto de linea
		jz _cont_incr			;incrementamos el contador
		jmp _procesar_lineas		;seguimos procesando el archivo
	_cont_incr:
		mov eax,[cont]	 		;recuperamos el contador desde memoria y lo pasamos a eax
		inc eax				;incrementamos el contador de lineas en una unidad
		mov [cont],eax			;actualizamos la variable "cont"
		mov ebx,[cParcial]		;recuperamos el contador parcial desde memoria y lo pasamos a ebx
		inc ebx				;incrementamos "cParcial" en una unidad
		mov [cParcial],ebx		;actualizamos la variable "cParcial"
		mov eax,[lineas]		;recuperamos el numero de lineas a mostrar
		cmp eax,ebx			;si "cParcial" es igual "lineas" entonces se termino una pagina 
		jz _escribir_contador		;imprimimos la linea que muestra el contador
		jmp _procesar_lineas		;sino, procesamos la siguiente linea
	_escribir_contador:
		mov eax, [cont]			;guardamos el contador de lineas en eax para ser mostrado por pantalla
		push ebx		
		xor ebx,ebx
		mov [cParcial],ebx		;inicializo el contador parcial en cero para la proxima vuelta
		pop ebx

;_print_int	
;Imprime un numero entero almacenado en eax, en el output definido.
;al finalizar la ejecucion restaura el registro eax
	_print_int:
		push eax			;preservamos eax
		push ecx			;preservamos ecx
		push edx			;preservamos edx
		xor edx,edx			;edx a 0, aca va ir el resto de la division
		mov ecx,10			;ecx es el divisor, lo inicializamos en 10
		div ecx				;dividimos eax por 10
		cmp eax,0			;el cociente es 0?
		je imprimir_digito		;imprime el digito que obtuvimos por la division(esta en edx el resto)
		lea eax,[eax+48]		;escribe en eax el valor de edx + 48(valor ascii del 0)
		mov [buffer],eax		;ponemos el digito en el buffer
		call _print_char		;llamamos a imprimir caracter
	imprimir_digito:
		lea eax,[edx+48]		;escribe en eax el valor de edx + 48(valor ascii del 0)
		mov [buffer],eax		;ponemos el digito en el buffer
		call _print_char		;llamamos a imprimir caracter
		pop edx				;recuperamos el resto de la division anterior
		pop ecx			;preservamos ecx
    		pop eax				;recuperamos el cociente anterior	
;----------------------------------------------------------------------------------------------------
		mov eax,4			;codigo sys_call write
		mov ebx,1			;file descriptor de stdout			
		mov ecx,txt_linea		;buffer de escritura				imprimo " lineas"	
		mov edx,len_linea		;cantidad de bytes a escribir
		int 80h	
;----------------------------------------------------------------------------------------------------

;_leer_teclado	
;Rutina para la lectura de un caracter de teclado
	_leer_teclado:
		call canonical_off		;
		call echo_off			;con esto metodos detenemos el modo canonico de la consola
		mov eax,3			;codigo sys_call read
		mov ebx,0 			;file descriptor stdin
		mov ecx,buffer			;buffer de lectura
		mov edx,1			;cantidad de bytes a leer
		int 80h				;invocacion al servicio del SO
		cmp eax,0			;preguntamos si eax es menor que 0
		js _show_err03			;si lo es, se muestra un mensaje de error desconocido
		mov al,[buffer]			;recuperamos la tecla presionada
		call canonical_on		;
		call echo_on			;con estos metodos volvemos el modo canonico de la consola
		cmp al,10			;preguntamos si es "Enter"
		jz _procesar_lineas		;si lo es, saltamos a procesar lineas	
		cmp al,32			;sino, preguntamos si es "Espacio"
		jz _una_linea			;si lo es, saltamos a procesar una sola linea
		jmp _show_err03			;si es cualquier otra tecla,
						;mostramos un mensaje de error desconocido

;----------------------------------------------------------------------------------------------------
	_una_linea:												;Procesa una linea
		call _read_char			;leemos un caracter
		cmp eax,0			;preguntamos si se termino de leer todo el archivo
		jz _eof				;si es asi, salta a fin de archivo
		call _print_char		;imprimimos el caracter leido
		mov al,[buffer]			
		cmp al,10			;comparamos el caracter leido con el caracter de salto de linea
		jz _c_incr			;incrementamos el contador				
		jmp _una_linea			;seguimos procesando el archivo
	_c_incr:
		mov eax,[cont]	 		;recuperamos el contador desde memoria y lo pasamos a eax
		inc eax				;incrementamos el contador de lineas en una unidad
		mov [cont],eax			;actualizamos la variable "cont"
		jmp _print_int
;----------------------------------------------------------------------------------------------------

;_eof					
;cierra archivo de entrada
	_eof:
		mov eax,[cont]			;imprimimos las lineas procesadas antes de cerrar el archivo
		call _print_cont_end
		mov eax, 6			;codigo sys_call close
		mov ebx,[fd_input]		;file descriptor archivo de entrada	
		int 80h				;invocacion al servicio del SO	
		cmp eax, 0			;preguntamos si eax en menor que 0
		js _show_err01			;si lo es, mostramos un error en el archivo
		jmp _exit			;sino, termina la ejecucion limpiamente

;----------------------------------------------------------------------------------------------------
;_print_cont_end										;imprime el ultimo contador
;Imprime el contador final									;ES UNA CHANCHADA PERO ANDA,
;al finalizar la ejecucion sigue la ejecucin de _eof						;Y MOOOY BIEN
	_print_cont_end:
		push eax			;preservamos eax
		push edx			;preservamos edx
		xor edx,edx			;edx a 0, aca va ir el resto de la division
		mov ecx,10			;ecx es el divisor, lo inicializamos en 10
		div ecx				;dividimos eax por 10
		cmp eax,0			;el cociente es 0?
		je imprimir_dig			;imprime el digito que obtuvimos por la division(esta en edx el resto)
		lea eax,[eax+48]		;escribe en eax el valor de edx + 48(valor ascii del 0)
		mov [buffer],eax		;ponemos el digito en el buffer
		call _print_char		;llamamos a imprimir caracter
	imprimir_dig:
		lea eax,[edx+48]		;escribe en eax el valor de edx + 48(valor ascii del 0)
		mov [buffer],eax		;ponemos el digito en el buffer
		call _print_char		;llamamos a imprimir caracter
		pop edx				;recuperamos el resto de la division anterior
    		pop eax				;recuperamos el cociente anterior		

;----------------------------------------------------------------------------------------------------
		mov eax,4			;codigo sys_call write
		mov ebx,1			;file descriptor de stdout			imprimo " lineas"
		mov ecx,txt_linea		;buffer de escritura
		mov edx,len_linea		;cantidad de bytes a escribir
		int 80h

		ret
;----------------------------------------------------------------------------------------------------
;----------------------------------------------------------------------------------------------------

;_read_char	
;Lee un caracter en el input, y lo almacena en buffer
	_read_char:
		mov eax,3
		mov ebx,[fd_input]
		mov ecx, buffer
		mov edx,1
		int 80h
		cmp eax,0			;verificamos si eax menor que 0
		js _show_err03			;si lo es, mostramos un mensaje de error desconocido
		ret

;_print_char
;Imprime un digito almacenado en eax por pantalla.
;al finalizar la ejecucion restaura los registros eax,edx
	_print_char:
		push eax
		push ebx			;guardo los registros por si eran importantes
		push ecx
		push edx
		mov eax, 4			;codigo sys_call write
		mov ebx, 1			;file descriptor de stdout---------------------------------------------------agregado
		mov ecx, buffer			;buffer de escritura
		mov edx, 1			;cantidad de bytes a escribir
		int 80h
		cmp eax, 0			;si eax < 0, se produjo un error
		js _show_err01
		pop edx
		pop ecx				;recupero los registros como estaban antes de iniciar la rutina
		pop ebx
		pop eax
		ret				;retorno

;_open_file
;Abre el archivo almacenado en ebx
	_open_file:
		mov eax,5
		mov ecx,0			;abro el archivo como solo lectura
		int 80h
		cmp eax, 0			;pregunto si se produjo algun error
		js _show_err01			;si no se pudo abrir el archivo, muestro un error
		ret

;es_h
;Setea al registro eax en 0 si el parametro pasado es "-h", o en 1 en caso contrario	
	es_h:
		cmp [ebx], byte 45		;compara el primer caracter con el simbolo '-'
		jnz no_es_h			;si no es '-', entonces no es "-h"
		cmp [ebx+1], byte 104		;compara el segundo caracter con la letra 'h'
		jnz no_es_h			;si no es la letra 'h', entonces no es "-h"
		cmp [ebx+2], byte 0		;verifica que no haya nada mas aparte de "-h"
		jnz no_es_h			;si lo hay, entonces no es "-h"
		mov eax,0			;indicamos que es "-h"
		ret
	no_es_h:
		mov eax,1			;indicamos que no es "-h"
		ret
;es_nXX
;Rutina encargada de controlar si se llamo con -nXX, retorna 0 en eax si se lo llamo con -nXX, 1 si no.
	es_nXX:
		cmp [ebx], byte 45		;compara el primer caracter con el simbolo '-'
		jnz no_es_nXX			;si no es '-', entonces no es "-nXX"
		cmp [ebx+1], byte 110		;compara el segundo caracter con la letra 'n'
		jnz no_es_nXX			;si no es 'n', entonces no es "-nXX"
		cmp [ebx+2], byte 48		;verifica si el tercer caracter es mayor o igual a 0
		jb no_es_nXX			;si no lo es, no es "-nXX"
		cmp [ebx+2], byte 57		;verifica si el tercer caracter es menor o igual a 9
		ja no_es_nXX			;si no lo es, no es "-nXX"
		cmp [ebx+3], byte 48		;verifica si el cuarto caracter es mayor o igual a 2
		jb no_es_nXX			;si no lo es, no es "-nXX"
		cmp [ebx+3], byte 57		;verifica si el cuarto caracter es menor o igual a 9
		ja no_es_nXX			;si no lo es, no es "-nXX"
		cmp [ebx+4], byte 0		;verifica que no haya nada mas aparte de "-nXX"
		jnz no_es_nXX			;si lo hay, entonces no es "-nXX"
		mov eax,0			;indicamos que es "-nXX"
		ret
	no_es_nXX:
		mov eax,1			;indicamos que no es "-nXX"
		ret

;_show_err01	
;Imprime un cartel en pantalla informando que se produjo un error en el 
;archivo de entrada
	_show_err01:
		mov eax,4		
		mov ebx,1
		mov ecx,err01			;imprimo por pantalla un error de tipo 1
		mov edx,len_err01
		int 80h
		
		mov eax,1
		mov ebx,1
		int 80h

;_show_err02	
;Imprime un cartel en pantalla informando que se produjo un error en los 
;parametros
	_show_err02:
		mov eax,4		
		mov ebx,1
		mov ecx,err02			;imprimo por pantalla un error de tipo 2
		mov edx,len_err02
		int 80h
		
		mov eax,1
		mov ebx,2
		int 80h

;_show_err03	
;Imprime un cartel en pantalla informando que se produjo un error
;desconocido
	_show_err03:
		mov eax,4		
		mov ebx,1
		mov ecx,err03			;imprimo por pantalla un erro de tipo 3
		mov edx,len_err03
		int 80h
		
		mov eax,1
		mov ebx,3
		int 80h


;_show_help	
;Muestra el mensaje de "Help" por pantalla
	_show_help:
		mov eax, 4			;codigo sys_call write
		mov ebx, 1			;file descriptor de la consola
		mov ecx, txt_help		;mensaje de "Help"
		mov edx, len_help		;largo del mensaje de ayuda
		int 80h				;invocacion al servicio del SO
						;Luego salimos del programa con el codigo indicando sin errores

;_exit	
;Finaliza la ejecucion con una terminacion normal
	_exit:		
		mov eax, 1
		mov ebx, 0
		int 80h
 
