assume cs:code
;函数应该保存用到的寄存器，我为了简化代码并没有这样做，这样做写代码时需要很小心安排寄存器使用
;大家在写的时候请尽量保存使用到的寄存器，简化编程;
;大项目请务必保存，C语言编译完在函数入口也是会保存使用到的寄存器的

;观察程序，体会程序在死循环中是怎么"抽空"执行其他代码的
;操作键为1和2，3是退出
stack segment 
    db 128 dup (0)
stack ends

data segment 
    dw 0, 0
    db 0 ;A 计数器
data ends

code segment
        assume ss:stack, cs:code
        jmp  start
 
 
        old_i8      dd  ?             ; 保存旧的时钟中断向量
        cursor      dw  ?             ; 保存旧的光标位置
        hour        dw  0             ; 保存当前小时数
        minute      dw  0             ; 保存当前分钟数
        second      dw  0             ; 保存当前分钟数
        tickcnt     dw  1             ; 时钟中断计数器
        obuf        db  "00:00:00"    ; 输出缓冲区
        str1        db  "this is message 1"
        str2        db  "this is message 2"
        str3        db  "this is message 3"

start:
        mov ax, stack
        mov ss, ax
        mov sp, 128;使用申请的栈

        call init ;安装新的中断例程
        call work ;假装在工作，体会"代码执行地址即cs:ip"切换的基本方式
        call restore ;恢复默认中断例程

        mov ax, 4c00h
        int 21h
        

;死循环，模拟在干活
work:
        xor dx, dx
    busy:
        cmp dx, 0
        jne return
        jmp busy
    return:
        ret


;参数在ax，把十位放到ch，个位放到cl
; ch = (ax / 10) % 10, cl = ax % 10 
; ch里放的是余数，指示该print哪个字符串
calculate:
        push bx
        push ax
        
        mov bl, 3
        div bl
        mov ch, ah
        mov cl, al

        pop ax
        pop bx
        ret
;按下A键，运行A函数
func1:
        push ax
        push bx
        push cx
        push dx
        inc byte ptr ds:[4]
        xor ah, ah
        mov al, ds:[4]
        call calculate
        push ax
        mov  ax, cs
        mov  es, ax
        pop ax
        cmp ch, 0
        je s1
        cmp ch, 1
        je s2
        cmp ch, 2
        je s3
        s1:
        mov  bp, offset str1    ; es:[bp] is the address of the string
        jmp go
        s2:
        mov  bp, offset str2    ; es:[bp] is the address of the string
        jmp go
        s3:
        mov  bp, offset str3    ; es:[bp] is the address of the string
        jmp go
        go:
        push ax
        mov  al, 0              ; flag
        mov  bh, 0              ; page
        mov  bl, 0Eh            ; character property
        mov  cx, 17              ; character count
        mov  dx, 20h            ; cursor potition
        mov  ah, 13h
        int  10h
        pop ax
        pop dx
        pop cx
        pop bx
        pop ax
        ret

;按下B键，运行B函数
func2:
        ; DOS功能调用2Ch：real-time -> ch:cl:dh
        push ax
        push cx
        push dx
        mov  ah, 2ch
        int  21h
        mov  byte ptr hour,   ch
        mov  byte ptr minute, cl
        mov  byte ptr second, dh
         ; hour -> obuf[0,1]
        mov  cx, 10
        mov  ax, hour
        div  cl
        add  al, 30h
        mov  obuf[0], al
        add  ah, 30h
        mov  obuf[1], ah
 
 
        ; minute -> obuf[3,4]
        mov  ax, minute
        div  cl
        add  al, 30h
        mov  obuf[3], al
        add  ah, 30h
        mov  obuf[4], ah
 
 
        ; second -> obuf[6,7]
        mov  ax, second
        div  cl
        add  al, 30h
        mov  obuf[6], al
        add  ah, 30h
        mov  obuf[7], ah
 
 
        ; display
        mov  ax, cs
        mov  es, ax
        mov  bp, offset obuf    ; es:[bp] is the address of the string
        mov  al, 0              ; flag
        mov  bh, 0              ; page
        mov  bl, 0Eh            ; character property
        mov  cx, 8              ; character count
        mov  dx, 46h            ; cursor potition
        mov  ah, 13h
        int  10h
        inc byte ptr ds:[5]
        xor ah, ah
        mov al, ds:[5]
        call calculate



        pop dx
        pop cx
        pop ax
        ret



;初始化中断例程
init:
        mov ax, data
        mov ds, ax

        mov ax, 0
        mov es, ax

        cli     ;关中断修改中断处理程序
        push es:[9 * 4]
        pop ds:[0]
        push es:[9 * 4 + 2]
        pop ds:[2] ;保存原来的9号中断例程地址

        mov word ptr es:[9 * 4], offset int9 ; 将键盘中断处理程序指向自己编写的例程
        mov es:[9 * 4 + 2], cs
        sti

        mov ax, 0b800h ;指向显存
        mov es, ax

        ret
;恢复之前的中断例程
restore:
        mov ax, 0
        mov es, ax
        mov ax, data
        mov ds, ax
        cli
        push ds:[0]
        pop es:[9 * 4]
        push ds:[2]
        pop es:[9 * 4 + 2]
        sti
        ret

;根据中断引发的键位，暂停work函数，执行对应的操作，然后继续执行work函数
int9:
        push ax ;注意这里保存用到的寄存器？？？？？
        push bx
        push es

        in al, 60h
        dec al

        pushf
        call dword ptr ds:[0]
        
        mov bx, 0b800h
        mov es, bx

        cmp al, 1 ; 1
        je f1
        cmp al, 2 ; 2
        je f2
        cmp al, 3 ; 3
        je f3
        jmp int9ret

    f1:
        call func1
        jmp int9ret
    f2:
        call func2
        jmp int9ret
    f3:
        inc dx ;使得dx不为0从而退出work函数中的死循环

    int9ret:
        pop es
        pop bx
        pop ax
        iret

code ends
end start