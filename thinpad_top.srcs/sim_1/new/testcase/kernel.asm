
kernel.elf:     file format elf32-littleriscv


Disassembly of section .text:

80000000 <INITLOCATE>:
    .section .text.init
    // 监控程序的入口点，是最先执行的代码
    // .text.init 段放在内存的 0x80000000 位置
INITLOCATE:
    // 跳转到 init.S:START
    la s10, START
80000000:	00000d17          	auipc	s10,0x0
80000004:	00cd0d13          	addi	s10,s10,12 # 8000000c <START>
    jr s10
80000008:	000d0067          	jr	s10

8000000c <START>:

    .global START
START:
    // 清空 BSS
    // _sbss 和 _ebss 在 ld script 中定义
    la s10, _sbss
8000000c:	007f0d17          	auipc	s10,0x7f0
80000010:	ff4d0d13          	addi	s10,s10,-12 # 807f0000 <_sbss>
    la s11, _ebss
80000014:	007f0d97          	auipc	s11,0x7f0
80000018:	104d8d93          	addi	s11,s11,260 # 807f0118 <_ebss>

8000001c <bss_init>:
bss_init:
    beq s10, s11, bss_init_done
8000001c:	01bd0863          	beq	s10,s11,8000002c <bss_init_done>
    sw  zero, 0(s10)
80000020:	000d2023          	sw	zero,0(s10)
    addi s10, s10, 4
80000024:	004d0d13          	addi	s10,s10,4
    j   bss_init
80000028:	ff5ff06f          	j	8000001c <bss_init>

8000002c <bss_init_done>:
    li t0, MIE_MTIE
    csrw mie, t0
#endif

    // 设置内核栈
    la sp, KERNEL_STACK_INIT
8000002c:	00800117          	auipc	sp,0x800
80000030:	fd410113          	addi	sp,sp,-44 # 80800000 <KERNEL_STACK_INIT>

    // 设置用户栈
    li t0, USER_STACK_INIT
80000034:	807f02b7          	lui	t0,0x807f0
    // 设置用户态程序的 sp(x2) 和 fp(x8) 寄存器
    // uregs_sp 和 uregs_fp 在 ld script 中定义
    la t1, uregs_sp
80000038:	007f0317          	auipc	t1,0x7f0
8000003c:	fcc30313          	addi	t1,t1,-52 # 807f0004 <uregs_sp>
    STORE t0, 0(t1)
80000040:	00532023          	sw	t0,0(t1)
    la t1, uregs_fp
80000044:	007f0317          	auipc	t1,0x7f0
80000048:	fd830313          	addi	t1,t1,-40 # 807f001c <uregs_fp>
    STORE t0, 0(t1)
8000004c:	00532023          	sw	t0,0(t1)

#ifdef ENABLE_UART16550
    // 配置串口，见 serial.h 中的叙述进行配置
    li t0, COM1
80000050:	100002b7          	lui	t0,0x10000
    // 打开 FIFO，并且清空 FIFO
    li t1, COM_FCR_CONFIG 
80000054:	00700313          	li	t1,7
    sb t1, %lo(COM_FCR_OFFSET)(t0)
80000058:	00628123          	sb	t1,2(t0) # 10000002 <INITLOCATE-0x6ffffffe>
    // 打开 DLAB
    li t1, COM_LCR_DLAB
8000005c:	08000313          	li	t1,128
    sb t1, %lo(COM_LCR_OFFSET)(t0)
80000060:	006281a3          	sb	t1,3(t0)
    // 设置 Baudrate
    li t1, COM_DLL_VAL
80000064:	00c00313          	li	t1,12
    sb t1, %lo(COM_DLL_OFFSET)(t0)
80000068:	00628023          	sb	t1,0(t0)
    sb x0, %lo(COM_DLM_OFFSET)(t0)
8000006c:	000280a3          	sb	zero,1(t0)
    // 关闭 DLAB，打开 WLEN8
    li t1, COM_LCR_CONFIG
80000070:	00300313          	li	t1,3
    sb t1, %lo(COM_LCR_OFFSET)(t0)
80000074:	006281a3          	sb	t1,3(t0)
    sb x0, %lo(COM_MCR_OFFSET)(t0)
80000078:	00028223          	sb	zero,4(t0)
    // 打开串口中断
    li t1, COM_IER_RDI
8000007c:	00100313          	li	t1,1
    sb t1, %lo(COM_IER_OFFSET)(t0)
80000080:	006280a3          	sb	t1,1(t0)
#endif

    // 从内核栈顶清空并留出 TF_SIZE 大小的空间用于存储中断帧
    li t0, TF_SIZE
80000084:	08000293          	li	t0,128
.LC0:
    addi t0, t0, -XLEN
80000088:	ffc28293          	addi	t0,t0,-4
    addi sp, sp, -XLEN
8000008c:	ffc10113          	addi	sp,sp,-4
    STORE zero, 0(sp)
80000090:	00012023          	sw	zero,0(sp)
    bne t0, zero, .LC0
80000094:	fe029ae3          	bnez	t0,80000088 <bss_init_done+0x5c>

    // 保存中断帧地址到 TCBT
    la t0, TCBT
80000098:	007f0297          	auipc	t0,0x7f0
8000009c:	06828293          	addi	t0,t0,104 # 807f0100 <TCBT>
    STORE sp, 0(t0)
800000a0:	0022a023          	sw	sp,0(t0)

    // t6 保存 idle 中断帧位置
    mv t6, sp
800000a4:	00010f93          	mv	t6,sp

    // 初始化栈空间
    li t0, TF_SIZE
800000a8:	08000293          	li	t0,128
.LC1:
    addi t0, t0, -XLEN
800000ac:	ffc28293          	addi	t0,t0,-4
    addi sp, sp, -XLEN
800000b0:	ffc10113          	addi	sp,sp,-4
    STORE zero, 0(sp)
800000b4:	00012023          	sw	zero,0(sp)
    bne t0, zero, .LC1
800000b8:	fe029ae3          	bnez	t0,800000ac <bss_init_done+0x80>

    // 载入TCBT地址
    la t0, TCBT
800000bc:	007f0297          	auipc	t0,0x7f0
800000c0:	04428293          	addi	t0,t0,68 # 807f0100 <TCBT>
    // thread1(shell/user) 的中断帧地址设置
    STORE sp, XLEN(t0)
800000c4:	0022a223          	sw	sp,4(t0)
    // 设置 idle 线程栈指针(调试用?)
    STORE sp, TF_sp(t6)
800000c8:	002fa223          	sw	sp,4(t6)

    // 取得 thread1 的 TCB 地址
    la t2, TCBT + XLEN
800000cc:	007f0397          	auipc	t2,0x7f0
800000d0:	03838393          	addi	t2,t2,56 # 807f0104 <TCBT+0x4>
    LOAD t2, 0(t2)
800000d4:	0003a383          	lw	t2,0(t2)
#ifdef ENABLE_INT
    // 设置当前线程为 thread1
    csrw mscratch, t2
#endif

    la t1, current
800000d8:	007f0317          	auipc	t1,0x7f0
800000dc:	03830313          	addi	t1,t1,56 # 807f0110 <current>
    sw t2, 0(t1)
800000e0:	00732023          	sw	t2,0(t1)
    csrw pmpaddr0, t0
#endif
#endif

    // 进入主线程
    j WELCOME
800000e4:	0040006f          	j	800000e8 <WELCOME>

800000e8 <WELCOME>:

WELCOME:
    // 装入启动信息并打印
    la a0, monitor_version
800000e8:	00001517          	auipc	a0,0x1
800000ec:	06c50513          	addi	a0,a0,108 # 80001154 <monitor_version>
    jal WRITE_SERIAL_STRING
800000f0:	32c000ef          	jal	ra,8000041c <WRITE_SERIAL_STRING>

    // 开始交互
    j SHELL
800000f4:	0040006f          	j	800000f8 <SHELL>

800000f8 <SHELL>:
     *  用户空间寄存器：x1-x31依次保存在 0x807F0000 连续 124 字节
     *  用户程序入口临时存储：0x807F0000
     */
SHELL:
    // 读操作符
    jal READ_SERIAL
800000f8:	344000ef          	jal	ra,8000043c <READ_SERIAL>

    // 根据操作符进行不同的操作
    li t0, 'R'
800000fc:	05200293          	li	t0,82
    beq a0, t0, .OP_R
80000100:	06550863          	beq	a0,t0,80000170 <.OP_R>
    li t0, 'D'
80000104:	04400293          	li	t0,68
    beq a0, t0, .OP_D
80000108:	0a550263          	beq	a0,t0,800001ac <.OP_D>
    li t0, 'A'
8000010c:	04100293          	li	t0,65
    beq a0, t0, .OP_A
80000110:	0c550e63          	beq	a0,t0,800001ec <.OP_A>
    li t0, 'G'
80000114:	04700293          	li	t0,71
    beq a0, t0, .OP_G
80000118:	10550c63          	beq	a0,t0,80000230 <.OP_G>
    li t0, 'T'
8000011c:	05400293          	li	t0,84
    beq a0, t0, .OP_T
80000120:	00550863          	beq	a0,t0,80000130 <.OP_T>

    // 错误的操作符，输出 XLEN，用于区分 RV32 和 RV64
    li a0, XLEN
80000124:	00400513          	li	a0,4
    // 把 XLEN 写给 term
    jal WRITE_SERIAL
80000128:	270000ef          	jal	ra,80000398 <WRITE_SERIAL>
    j .DONE
8000012c:	2400006f          	j	8000036c <.DONE>

80000130 <.OP_T>:

.OP_T:
    // 操作 - 打印页表
    // 保存寄存器
    addi sp, sp, -3*XLEN
80000130:	ff410113          	addi	sp,sp,-12
    STORE s1, 0(sp)
80000134:	00912023          	sw	s1,0(sp)
    STORE s2, XLEN(sp)
80000138:	01212223          	sw	s2,4(sp)

#ifdef ENABLE_PAGING
    csrr s1, satp
    slli s1, s1, 12
#else
    li s1, -1
8000013c:	fff00493          	li	s1,-1
#endif
    STORE s1, 2*XLEN(sp)
80000140:	00912423          	sw	s1,8(sp)
    addi s1, sp, 2*XLEN
80000144:	00810493          	addi	s1,sp,8
    li s2, XLEN
80000148:	00400913          	li	s2,4
.LC0:
    // 读取内存并写入串口
    lb a0, 0(s1)
8000014c:	00048503          	lb	a0,0(s1)
    addi s2, s2, -1
80000150:	fff90913          	addi	s2,s2,-1
    jal WRITE_SERIAL
80000154:	244000ef          	jal	ra,80000398 <WRITE_SERIAL>
    addi s1, s1, 0x1
80000158:	00148493          	addi	s1,s1,1
    bne s2, zero, .LC0
8000015c:	fe0918e3          	bnez	s2,8000014c <.OP_T+0x1c>

    // 恢复寄存器
    LOAD s1, 0x0(sp)
80000160:	00012483          	lw	s1,0(sp)
    LOAD s2, XLEN(sp)
80000164:	00412903          	lw	s2,4(sp)
    addi sp, sp, 3*XLEN
80000168:	00c10113          	addi	sp,sp,12

    j .DONE
8000016c:	2000006f          	j	8000036c <.DONE>

80000170 <.OP_R>:

.OP_R:
    // 操作 - 打印用户空间寄存器
    // 保存 s1, s2
    addi sp, sp, -2*XLEN
80000170:	ff810113          	addi	sp,sp,-8
    STORE s1, 0(sp)
80000174:	00912023          	sw	s1,0(sp)
    STORE s2, XLEN(sp)
80000178:	01212223          	sw	s2,4(sp)

    // 打印 31 个寄存器
    la s1, uregs
8000017c:	007f0497          	auipc	s1,0x7f0
80000180:	e8448493          	addi	s1,s1,-380 # 807f0000 <_sbss>
    li s2, 31*XLEN
80000184:	07c00913          	li	s2,124
.LC1:
    // 读取内存并写入串口
    lb a0, 0(s1)
80000188:	00048503          	lb	a0,0(s1)
    addi s2, s2, -1
8000018c:	fff90913          	addi	s2,s2,-1
    jal WRITE_SERIAL
80000190:	208000ef          	jal	ra,80000398 <WRITE_SERIAL>
    addi s1, s1, 0x1
80000194:	00148493          	addi	s1,s1,1
    bne s2, zero, .LC1
80000198:	fe0918e3          	bnez	s2,80000188 <.OP_R+0x18>

    // 恢复s1,s2
    LOAD s1, 0(sp)
8000019c:	00012483          	lw	s1,0(sp)
    LOAD s2, XLEN(sp)
800001a0:	00412903          	lw	s2,4(sp)
    addi sp, sp, 2*XLEN
800001a4:	00810113          	addi	sp,sp,8
    j .DONE
800001a8:	1c40006f          	j	8000036c <.DONE>

800001ac <.OP_D>:

.OP_D:
    // 操作 - 打印内存 num 个字节
    // 保存 s1, s2
    addi sp, sp, -2*XLEN
800001ac:	ff810113          	addi	sp,sp,-8
    STORE s1, 0(sp)
800001b0:	00912023          	sw	s1,0(sp)
    STORE s2, XLEN(sp)
800001b4:	01212223          	sw	s2,4(sp)

    // 获得 addr
    jal READ_SERIAL_XLEN
800001b8:	320000ef          	jal	ra,800004d8 <READ_SERIAL_XLEN>
    or s1, a0, zero
800001bc:	000564b3          	or	s1,a0,zero
    // 获得 num
    jal READ_SERIAL_XLEN
800001c0:	318000ef          	jal	ra,800004d8 <READ_SERIAL_XLEN>
    or s2, a0, zero
800001c4:	00056933          	or	s2,a0,zero

.LC2:
    // 读取内存并写入串口
    lb a0, 0(s1)
800001c8:	00048503          	lb	a0,0(s1)
    addi s2, s2, -1
800001cc:	fff90913          	addi	s2,s2,-1
    jal WRITE_SERIAL
800001d0:	1c8000ef          	jal	ra,80000398 <WRITE_SERIAL>
    addi s1, s1, 0x1
800001d4:	00148493          	addi	s1,s1,1
    bne s2, zero, .LC2
800001d8:	fe0918e3          	bnez	s2,800001c8 <.OP_D+0x1c>

    // 恢复 s1, s2
    LOAD s1, 0(sp)                    
800001dc:	00012483          	lw	s1,0(sp)
    LOAD s2, XLEN(sp)
800001e0:	00412903          	lw	s2,4(sp)
    addi sp, sp, 2*XLEN
800001e4:	00810113          	addi	sp,sp,8
    j .DONE
800001e8:	1840006f          	j	8000036c <.DONE>

800001ec <.OP_A>:

.OP_A:
    // 操作 - 写入内存 num 字节，num 为 4 的倍数
    // 保存 s1, s2
    addi sp, sp, -2*XLEN
800001ec:	ff810113          	addi	sp,sp,-8
    STORE s1, 0(sp)
800001f0:	00912023          	sw	s1,0(sp)
    STORE s2, 4(sp)
800001f4:	01212223          	sw	s2,4(sp)

    // 获得 addr
    jal READ_SERIAL_XLEN
800001f8:	2e0000ef          	jal	ra,800004d8 <READ_SERIAL_XLEN>
    or s1, a0, zero
800001fc:	000564b3          	or	s1,a0,zero

    // 获得 num
    jal READ_SERIAL_XLEN
80000200:	2d8000ef          	jal	ra,800004d8 <READ_SERIAL_XLEN>
    or s2, a0, zero
80000204:	00056933          	or	s2,a0,zero

    // num 除 4，获得字数
    srl s2, s2, 2
80000208:	00295913          	srli	s2,s2,0x2

.LC3:
    // 每次写入一字
    // 从串口读入一字
    jal READ_SERIAL_WORD
8000020c:	24c000ef          	jal	ra,80000458 <READ_SERIAL_WORD>
    // 写内存一字
    sw a0, 0(s1)
80000210:	00a4a023          	sw	a0,0(s1)
    addi s2, s2, -1
80000214:	fff90913          	addi	s2,s2,-1
    addi s1, s1, 4
80000218:	00448493          	addi	s1,s1,4
    bne s2, zero, .LC3
8000021c:	fe0918e3          	bnez	s2,8000020c <.OP_A+0x20>
    // 有 Cache 时让写入的代码生效
    fence.i
#endif

    // 恢复 s1, s2
    LOAD s1, 0(sp)
80000220:	00012483          	lw	s1,0(sp)
    LOAD s2, XLEN(sp)
80000224:	00412903          	lw	s2,4(sp)
    addi sp, sp, 2*XLEN
80000228:	00810113          	addi	sp,sp,8
    j .DONE
8000022c:	1400006f          	j	8000036c <.DONE>

80000230 <.OP_G>:

.OP_G:
    // 操作 - 跳转到用户程序执行
    // 获取 addr
    jal READ_SERIAL_XLEN
80000230:	2a8000ef          	jal	ra,800004d8 <READ_SERIAL_XLEN>
    // 保存到 s10
    mv s10, a0
80000234:	00050d13          	mv	s10,a0

    // 写开始计时信号
    // 告诉终端用户程序开始运行
    li a0, SIG_TIMERSET
80000238:	00600513          	li	a0,6
    jal WRITE_SERIAL
8000023c:	15c000ef          	jal	ra,80000398 <WRITE_SERIAL>
#endif

#endif

    // 定位用户空间寄存器备份地址
    la ra, uregs
80000240:	007f0097          	auipc	ra,0x7f0
80000244:	dc008093          	addi	ra,ra,-576 # 807f0000 <_sbss>
    // 保存栈指针
    STORE sp, TF_ksp(ra)
80000248:	0820a023          	sw	sp,128(ra)

    // x1 就是 ra
    // LOAD x1,  TF_ra(ra)
    LOAD sp, TF_sp(ra)
8000024c:	0040a103          	lw	sp,4(ra)
    LOAD gp, TF_gp(ra)
80000250:	0080a183          	lw	gp,8(ra)
    LOAD tp, TF_tp(ra)
80000254:	00c0a203          	lw	tp,12(ra)
    LOAD t0, TF_t0(ra)
80000258:	0100a283          	lw	t0,16(ra)
    LOAD t1, TF_t1(ra)
8000025c:	0140a303          	lw	t1,20(ra)
    LOAD t2, TF_t2(ra)
80000260:	0180a383          	lw	t2,24(ra)
    LOAD s0, TF_s0(ra)
80000264:	01c0a403          	lw	s0,28(ra)
    LOAD s1, TF_s1(ra)
80000268:	0200a483          	lw	s1,32(ra)
    LOAD a0, TF_a0(ra)
8000026c:	0240a503          	lw	a0,36(ra)
    LOAD a1, TF_a1(ra)
80000270:	0280a583          	lw	a1,40(ra)
    LOAD a2, TF_a2(ra)
80000274:	02c0a603          	lw	a2,44(ra)
    LOAD a3, TF_a3(ra)
80000278:	0300a683          	lw	a3,48(ra)
    LOAD a4, TF_a4(ra)
8000027c:	0340a703          	lw	a4,52(ra)
    LOAD a5, TF_a5(ra)
80000280:	0380a783          	lw	a5,56(ra)
    LOAD a6, TF_a6(ra)
80000284:	03c0a803          	lw	a6,60(ra)
    LOAD a7, TF_a7(ra)
80000288:	0400a883          	lw	a7,64(ra)
    LOAD s2, TF_s2(ra)
8000028c:	0440a903          	lw	s2,68(ra)
    LOAD s3, TF_s3(ra)
80000290:	0480a983          	lw	s3,72(ra)
    LOAD s4, TF_s4(ra)
80000294:	04c0aa03          	lw	s4,76(ra)
    LOAD s5, TF_s5(ra)
80000298:	0500aa83          	lw	s5,80(ra)
    LOAD s6, TF_s6(ra)
8000029c:	0540ab03          	lw	s6,84(ra)
    LOAD s7, TF_s7(ra)
800002a0:	0580ab83          	lw	s7,88(ra)
    LOAD s8, TF_s8(ra)
800002a4:	05c0ac03          	lw	s8,92(ra)
    LOAD s9, TF_s9(ra)
800002a8:	0600ac83          	lw	s9,96(ra)
    // s10 用来保存用户程序地址
    // LOAD s10, TF_s10(ra)
    LOAD s11, TF_s11(ra)
800002ac:	0680ad83          	lw	s11,104(ra)
    LOAD t3, TF_t3(ra)
800002b0:	06c0ae03          	lw	t3,108(ra)
    LOAD t4, TF_t4(ra)
800002b4:	0700ae83          	lw	t4,112(ra)
    LOAD t5, TF_t5(ra)
800002b8:	0740af03          	lw	t5,116(ra)
    LOAD t6, TF_t6(ra)
800002bc:	0780af83          	lw	t6,120(ra)

800002c0 <.ENTER_UESR>:
    la ra, .USERRET_USER
    // 进入用户程序
    mret
#else
    // ra 写入返回地址
    la ra, .USERRET2
800002c0:	00000097          	auipc	ra,0x0
800002c4:	00c08093          	addi	ra,ra,12 # 800002cc <.USERRET2>
    jr s10
800002c8:	000d0067          	jr	s10

800002cc <.USERRET2>:
    j .DONE
#endif

.USERRET2:
    // 定位用户空间寄存器备份地址
    la ra, uregs
800002cc:	007f0097          	auipc	ra,0x7f0
800002d0:	d3408093          	addi	ra,ra,-716 # 807f0000 <_sbss>

    // 不能先恢复 ra
    //STORE ra, TF_ra(ra)
    STORE sp, TF_sp(ra)
800002d4:	0020a223          	sw	sp,4(ra)
    STORE gp, TF_gp(ra)
800002d8:	0030a423          	sw	gp,8(ra)
    STORE tp, TF_tp(ra)
800002dc:	0040a623          	sw	tp,12(ra)
    STORE t0, TF_t0(ra)
800002e0:	0050a823          	sw	t0,16(ra)
    STORE t1, TF_t1(ra)
800002e4:	0060aa23          	sw	t1,20(ra)
    STORE t2, TF_t2(ra)
800002e8:	0070ac23          	sw	t2,24(ra)
    STORE s0, TF_s0(ra)
800002ec:	0080ae23          	sw	s0,28(ra)
    STORE s1, TF_s1(ra)
800002f0:	0290a023          	sw	s1,32(ra)
    STORE a0, TF_a0(ra)
800002f4:	02a0a223          	sw	a0,36(ra)
    STORE a1, TF_a1(ra)
800002f8:	02b0a423          	sw	a1,40(ra)
    STORE a2, TF_a2(ra)
800002fc:	02c0a623          	sw	a2,44(ra)
    STORE a3, TF_a3(ra)
80000300:	02d0a823          	sw	a3,48(ra)
    STORE a4, TF_a4(ra)
80000304:	02e0aa23          	sw	a4,52(ra)
    STORE a5, TF_a5(ra)
80000308:	02f0ac23          	sw	a5,56(ra)
    STORE a6, TF_a6(ra)
8000030c:	0300ae23          	sw	a6,60(ra)
    STORE a7, TF_a7(ra)
80000310:	0510a023          	sw	a7,64(ra)
    STORE s2, TF_s2(ra)
80000314:	0520a223          	sw	s2,68(ra)
    STORE s3, TF_s3(ra)
80000318:	0530a423          	sw	s3,72(ra)
    STORE s4, TF_s4(ra)
8000031c:	0540a623          	sw	s4,76(ra)
    STORE s5, TF_s5(ra)
80000320:	0550a823          	sw	s5,80(ra)
    STORE s6, TF_s6(ra)
80000324:	0560aa23          	sw	s6,84(ra)
    STORE s7, TF_s7(ra)
80000328:	0570ac23          	sw	s7,88(ra)
    STORE s8, TF_s8(ra)
8000032c:	0580ae23          	sw	s8,92(ra)
    STORE s9, TF_s9(ra)
80000330:	0790a023          	sw	s9,96(ra)
    STORE s10, TF_s10(ra)
80000334:	07a0a223          	sw	s10,100(ra)
    STORE s11, TF_s11(ra)
80000338:	07b0a423          	sw	s11,104(ra)
    STORE t3, TF_t3(ra)
8000033c:	07c0a623          	sw	t3,108(ra)
    STORE t4, TF_t4(ra)
80000340:	07d0a823          	sw	t4,112(ra)
    STORE t5, TF_t5(ra)
80000344:	07e0aa23          	sw	t5,116(ra)
    STORE t6, TF_t6(ra)
80000348:	07f0ac23          	sw	t6,120(ra)

    // 重新获得当前监控程序栈顶指针
    LOAD sp, TF_ksp(ra)
8000034c:	0800a103          	lw	sp,128(ra)
    mv a0, ra
80000350:	00008513          	mv	a0,ra
    la ra, .USERRET2
80000354:	00000097          	auipc	ra,0x0
80000358:	f7808093          	addi	ra,ra,-136 # 800002cc <.USERRET2>
    STORE ra, TF_ra(a0)
8000035c:	00152023          	sw	ra,0(a0)

    // 发送停止计时信号
    li a0, SIG_TIMETOKEN
80000360:	00700513          	li	a0,7
    // 告诉终端用户程序结束运行
    jal WRITE_SERIAL
80000364:	034000ef          	jal	ra,80000398 <WRITE_SERIAL>

    j .DONE
80000368:	0040006f          	j	8000036c <.DONE>

8000036c <.DONE>:

.DONE:
    // 交互循环
    j SHELL
8000036c:	d8dff06f          	j	800000f8 <SHELL>

80000370 <EXCEPTION_HANDLER>:
    .endr

#else
HALT:
EXCEPTION_HANDLER:
    j HALT
80000370:	0000006f          	j	80000370 <EXCEPTION_HANDLER>

80000374 <FATAL>:
#endif

FATAL:
    // 严重问题，重启
    // 错误信号
    li a0, SIG_FATAL
80000374:	08000513          	li	a0,128
    // 发送
    jal WRITE_SERIAL
80000378:	020000ef          	jal	ra,80000398 <WRITE_SERIAL>
    csrrs a0, mcause, zero
    jal WRITE_SERIAL_XLEN
    csrrs a0, mtval, zero
    jal WRITE_SERIAL_XLEN
#else
    mv a0, zero
8000037c:	00000513          	li	a0,0
    jal WRITE_SERIAL_XLEN
80000380:	084000ef          	jal	ra,80000404 <WRITE_SERIAL_XLEN>
    jal WRITE_SERIAL_XLEN
80000384:	080000ef          	jal	ra,80000404 <WRITE_SERIAL_XLEN>
    jal WRITE_SERIAL_XLEN
80000388:	07c000ef          	jal	ra,80000404 <WRITE_SERIAL_XLEN>
#endif

    // 重启地址
    la a0, START
8000038c:	00000517          	auipc	a0,0x0
80000390:	c8050513          	addi	a0,a0,-896 # 8000000c <START>
    jr a0
80000394:	00050067          	jr	a0

80000398 <WRITE_SERIAL>:
    .global READ_SERIAL
    .global READ_SERIAL_WORD
    .global READ_SERIAL_XLEN

WRITE_SERIAL:                       // 写串口：将a0的低八位写入串口
    li t0, COM1
80000398:	100002b7          	lui	t0,0x10000

8000039c <.TESTW>:
.TESTW:
    lb t1, %lo(COM_LSR_OFFSET)(t0)  // 查看串口状态
8000039c:	00528303          	lb	t1,5(t0) # 10000005 <INITLOCATE-0x6ffffffb>
    andi t1, t1, COM_LSR_THRE       // 截取写状态位
800003a0:	02037313          	andi	t1,t1,32
    bne t1, zero, .WSERIAL          // 状态位非零可写进入写
800003a4:	00031463          	bnez	t1,800003ac <.WSERIAL>
    j .TESTW                        // 检测验证，忙等待
800003a8:	ff5ff06f          	j	8000039c <.TESTW>

800003ac <.WSERIAL>:
.WSERIAL:
    sb a0, %lo(COM_THR_OFFSET)(t0)  // 写入寄存器a0中的值
800003ac:	00a28023          	sb	a0,0(t0)
    jr ra
800003b0:	00008067          	ret

800003b4 <WRITE_SERIAL_WORD>:

WRITE_SERIAL_WORD:
    addi sp, sp, -2*XLEN
800003b4:	ff810113          	addi	sp,sp,-8
    STORE ra, 0x0(sp)
800003b8:	00112023          	sw	ra,0(sp)
    STORE s0, XLEN(sp)
800003bc:	00812223          	sw	s0,4(sp)

    mv s0, a0
800003c0:	00050413          	mv	s0,a0

    andi a0, a0, 0xFF
800003c4:	0ff57513          	andi	a0,a0,255
    jal WRITE_SERIAL
800003c8:	fd1ff0ef          	jal	ra,80000398 <WRITE_SERIAL>
    srli a0, s0, 8
800003cc:	00845513          	srli	a0,s0,0x8

    andi a0, a0, 0xFF
800003d0:	0ff57513          	andi	a0,a0,255
    jal WRITE_SERIAL
800003d4:	fc5ff0ef          	jal	ra,80000398 <WRITE_SERIAL>
    srli a0, s0, 16
800003d8:	01045513          	srli	a0,s0,0x10

    andi a0, a0, 0xFF
800003dc:	0ff57513          	andi	a0,a0,255
    jal WRITE_SERIAL
800003e0:	fb9ff0ef          	jal	ra,80000398 <WRITE_SERIAL>
    srli a0, s0, 24
800003e4:	01845513          	srli	a0,s0,0x18

    andi a0, a0, 0xFF
800003e8:	0ff57513          	andi	a0,a0,255
    jal WRITE_SERIAL
800003ec:	fadff0ef          	jal	ra,80000398 <WRITE_SERIAL>
    mv a0, s0
800003f0:	00040513          	mv	a0,s0

    LOAD ra, 0x0(sp)
800003f4:	00012083          	lw	ra,0(sp)
    LOAD s0, XLEN(sp)
800003f8:	00412403          	lw	s0,4(sp)
    addi sp, sp, 2*XLEN
800003fc:	00810113          	addi	sp,sp,8

    jr ra
80000400:	00008067          	ret

80000404 <WRITE_SERIAL_XLEN>:

WRITE_SERIAL_XLEN:
    addi sp, sp, -XLEN
80000404:	ffc10113          	addi	sp,sp,-4
    STORE ra, 0x0(sp)
80000408:	00112023          	sw	ra,0(sp)

    jal WRITE_SERIAL_WORD
8000040c:	fa9ff0ef          	jal	ra,800003b4 <WRITE_SERIAL_WORD>
#ifdef RV64
    srli a0, a0, 32
    jal WRITE_SERIAL_WORD
#endif
    LOAD ra, 0x0(sp)
80000410:	00012083          	lw	ra,0(sp)
    addi sp, sp, XLEN
80000414:	00410113          	addi	sp,sp,4

    jr ra
80000418:	00008067          	ret

8000041c <WRITE_SERIAL_STRING>:

WRITE_SERIAL_STRING:                // 写字符串：将 a0 地址开始处的字符串写入串口
    mv a1, a0
8000041c:	00050593          	mv	a1,a0
    mv a2, ra
80000420:	00008613          	mv	a2,ra
    lb a0, 0(a1)
80000424:	00058503          	lb	a0,0(a1)
0:  jal WRITE_SERIAL                // 调用串口写函数
80000428:	f71ff0ef          	jal	ra,80000398 <WRITE_SERIAL>
    addi a1, a1, 0x1
8000042c:	00158593          	addi	a1,a1,1
    lb a0, 0(a1)
80000430:	00058503          	lb	a0,0(a1)
    bne a0, zero, 0b                // 打印循环至 0 结束符
80000434:	fe051ae3          	bnez	a0,80000428 <WRITE_SERIAL_STRING+0xc>
    jr a2
80000438:	00060067          	jr	a2

8000043c <READ_SERIAL>:

READ_SERIAL:                        // 读串口：将读到的数据写入a0低八位
    li t0, COM1
8000043c:	100002b7          	lui	t0,0x10000

80000440 <.TESTR>:
.TESTR:
    lb t1, %lo(COM_LSR_OFFSET)(t0)
80000440:	00528303          	lb	t1,5(t0) # 10000005 <INITLOCATE-0x6ffffffb>
    andi t1, t1, COM_LSR_DR         // 截取读状态位
80000444:	00137313          	andi	t1,t1,1
    bne t1, zero, .RSERIAL          // 状态位非零可读进入读
80000448:	00031463          	bnez	t1,80000450 <.RSERIAL>
    j .TESTR                        // 检测验证
8000044c:	ff5ff06f          	j	80000440 <.TESTR>

80000450 <.RSERIAL>:
.RSERIAL:
    lb a0, %lo(COM_RBR_OFFSET)(t0)
80000450:	00028503          	lb	a0,0(t0)
    jr ra
80000454:	00008067          	ret

80000458 <READ_SERIAL_WORD>:

READ_SERIAL_WORD:
    addi sp, sp, -5*XLEN             // 保存ra,s0-3
80000458:	fec10113          	addi	sp,sp,-20
    STORE ra, 0x0(sp)
8000045c:	00112023          	sw	ra,0(sp)
    STORE s0, XLEN(sp)
80000460:	00812223          	sw	s0,4(sp)
    STORE s1, 2*XLEN(sp)
80000464:	00912423          	sw	s1,8(sp)
    STORE s2, 3*XLEN(sp)
80000468:	01212623          	sw	s2,12(sp)
    STORE s3, 4*XLEN(sp)
8000046c:	01312823          	sw	s3,16(sp)

    jal READ_SERIAL                 // 读串口获得八个比特
80000470:	fcdff0ef          	jal	ra,8000043c <READ_SERIAL>
    or s0, zero, a0                 // 结果存入s0
80000474:	00a06433          	or	s0,zero,a0
    jal READ_SERIAL                 // 读串口获得八个比特
80000478:	fc5ff0ef          	jal	ra,8000043c <READ_SERIAL>
    or s1, zero, a0                 // 结果存入s1
8000047c:	00a064b3          	or	s1,zero,a0
    jal READ_SERIAL                 // 读串口获得八个比特
80000480:	fbdff0ef          	jal	ra,8000043c <READ_SERIAL>
    or s2, zero, a0                 // 结果存入s2
80000484:	00a06933          	or	s2,zero,a0
    jal READ_SERIAL                 // 读串口获得八个比特
80000488:	fb5ff0ef          	jal	ra,8000043c <READ_SERIAL>
    or s3, zero, a0                 // 结果存入s3
8000048c:	00a069b3          	or	s3,zero,a0

    andi s0, s0, 0x00FF             // 截取低八位
80000490:	0ff47413          	andi	s0,s0,255
    andi s1, s1, 0x00FF
80000494:	0ff4f493          	andi	s1,s1,255
    andi s2, s2, 0x00FF
80000498:	0ff97913          	andi	s2,s2,255
    andi s3, s3, 0x00FF
8000049c:	0ff9f993          	andi	s3,s3,255
    or a0, zero, s3                 // 存高八位
800004a0:	01306533          	or	a0,zero,s3
    sll a0, a0, 8                   // 左移
800004a4:	00851513          	slli	a0,a0,0x8
    or a0, a0, s2                   // 存八位
800004a8:	01256533          	or	a0,a0,s2
    sll a0, a0, 8                   // 左移
800004ac:	00851513          	slli	a0,a0,0x8
    or a0, a0, s1                   // 存八位
800004b0:	00956533          	or	a0,a0,s1
    sll a0, a0, 8                   // 左移
800004b4:	00851513          	slli	a0,a0,0x8
    or a0, a0, s0                   // 存低八位
800004b8:	00856533          	or	a0,a0,s0

    LOAD ra, 0x0(sp)                // 恢复ra,s0
800004bc:	00012083          	lw	ra,0(sp)
    LOAD s0, XLEN(sp)
800004c0:	00412403          	lw	s0,4(sp)
    LOAD s1, 2*XLEN(sp)
800004c4:	00812483          	lw	s1,8(sp)
    LOAD s2, 3*XLEN(sp)
800004c8:	00c12903          	lw	s2,12(sp)
    LOAD s3, 4*XLEN(sp)
800004cc:	01012983          	lw	s3,16(sp)
    addi sp, sp, 5*XLEN
800004d0:	01410113          	addi	sp,sp,20
    jr ra
800004d4:	00008067          	ret

800004d8 <READ_SERIAL_XLEN>:

READ_SERIAL_XLEN:
    addi sp, sp, -2*XLEN             // 保存ra,s0-3
800004d8:	ff810113          	addi	sp,sp,-8
    STORE ra, 0x0(sp)
800004dc:	00112023          	sw	ra,0(sp)
    STORE s0, XLEN(sp)
800004e0:	00812223          	sw	s0,4(sp)

    jal READ_SERIAL_WORD
800004e4:	f75ff0ef          	jal	ra,80000458 <READ_SERIAL_WORD>
    mv s0, a0
800004e8:	00050413          	mv	s0,a0
#ifdef RV64
    jal READ_SERIAL_WORD
    sll a0, a0, 32
    add s0, s0, a0
#endif
    mv a0, s0
800004ec:	00040513          	mv	a0,s0
    LOAD ra, 0x0(sp)                // 恢复ra,s0
800004f0:	00012083          	lw	ra,0(sp)
    LOAD s0, XLEN(sp)
800004f4:	00412403          	lw	s0,4(sp)
    addi sp, sp, 2*XLEN
800004f8:	00810113          	addi	sp,sp,8
    jr ra
800004fc:	00008067          	ret
	...

80001000 <UTEST_SIMPLE>:

    .section .text.utest
    .p2align 2

UTEST_SIMPLE:
    addi t5, t5, 0x1
80001000:	001f0f13          	addi	t5,t5,1
    jr ra
80001004:	00008067          	ret

80001008 <UTEST_1PTB>:
    /*  性能标定程序(1)
     *  这段程序一般没有数据冲突和结构冲突，可作为性能标定。
     *  执行这段程序需至少 320M 指令
     */
UTEST_1PTB:
    li t0, TESTLOOP64         // 装入 64M
80001008:	040002b7          	lui	t0,0x4000
.LC0:
    addi t0, t0, -1                // 滚动计数器
8000100c:	fff28293          	addi	t0,t0,-1 # 3ffffff <INITLOCATE-0x7c000001>
    li t1, 0
80001010:	00000313          	li	t1,0
    li t2, 1
80001014:	00100393          	li	t2,1
    li t3, 2
80001018:	00200e13          	li	t3,2
    bne t0, zero, .LC0
8000101c:	fe0298e3          	bnez	t0,8000100c <UTEST_1PTB+0x4>
    jr ra
80001020:	00008067          	ret

80001024 <UTEST_2DCT>:
    /*  运算数据冲突的效率测试(2)
     *  这段程序含有大量数据冲突，可测试数据冲突对效率的影响。
     *  执行这段程序需至少 176M 指令。
     */
UTEST_2DCT:
    lui t0, %hi(TESTLOOP16)         // 装入16M
80001024:	010002b7          	lui	t0,0x1000
    li t1, 1
80001028:	00100313          	li	t1,1
    li t2, 2
8000102c:	00200393          	li	t2,2
    li t3, 3
80001030:	00300e13          	li	t3,3
.LC1:
    xor t2, t2, t1                  // 交换t1,t2
80001034:	0063c3b3          	xor	t2,t2,t1
    xor t1, t1, t2
80001038:	00734333          	xor	t1,t1,t2
    xor t2, t2, t1
8000103c:	0063c3b3          	xor	t2,t2,t1
    xor t3, t3, t2                  // 交换t2,t3
80001040:	007e4e33          	xor	t3,t3,t2
    xor t2, t2, t3
80001044:	01c3c3b3          	xor	t2,t2,t3
    xor t3, t3, t2
80001048:	007e4e33          	xor	t3,t3,t2
    xor t1, t1, t3                  // 交换t3,t1
8000104c:	01c34333          	xor	t1,t1,t3
    xor t3, t3, t1
80001050:	006e4e33          	xor	t3,t3,t1
    xor t1, t1, t3
80001054:	01c34333          	xor	t1,t1,t3
    addi t0, t0, -1
80001058:	fff28293          	addi	t0,t0,-1 # ffffff <INITLOCATE-0x7f000001>
    bne t0, zero, .LC1
8000105c:	fc029ce3          	bnez	t0,80001034 <UTEST_2DCT+0x10>
    jr ra
80001060:	00008067          	ret

80001064 <UTEST_3CCT>:
    /*  控制指令冲突测试(3)
     *  这段程序有大量控制冲突。
     *  执行需要至少 256M 指令。
     */
UTEST_3CCT:
    lui t0, %hi(TESTLOOP64)         // 装入64M
80001064:	040002b7          	lui	t0,0x4000
.LC2_0:
    bne t0, zero, .LC2_1
80001068:	00029463          	bnez	t0,80001070 <UTEST_3CCT+0xc>
    jr ra
8000106c:	00008067          	ret
.LC2_1:
    j .LC2_2
80001070:	0040006f          	j	80001074 <UTEST_3CCT+0x10>
.LC2_2:
    addi t0, t0, -1
80001074:	fff28293          	addi	t0,t0,-1 # 3ffffff <INITLOCATE-0x7c000001>
    j .LC2_0
80001078:	ff1ff06f          	j	80001068 <UTEST_3CCT+0x4>
    addi t0, t0, -1
8000107c:	fff28293          	addi	t0,t0,-1

80001080 <UTEST_4MDCT>:
    /*  访存相关数据冲突测试(4)
     *  这段程序反复对内存进行有数据冲突的读写。
     *  需要至少执行 192M 指令。
     */
UTEST_4MDCT:
    lui t0, %hi(TESTLOOP32)          // 装入32M
80001080:	020002b7          	lui	t0,0x2000
    addi sp, sp, -4
80001084:	ffc10113          	addi	sp,sp,-4
.LC3:
    sw t0, 0(sp)
80001088:	00512023          	sw	t0,0(sp)
    lw t1, 0(sp)
8000108c:	00012303          	lw	t1,0(sp)
    addi t1, t1, -1
80001090:	fff30313          	addi	t1,t1,-1
    sw t1, 0(sp)
80001094:	00612023          	sw	t1,0(sp)
    lw t0, 0(sp)
80001098:	00012283          	lw	t0,0(sp)
    bne t0, zero, .LC3
8000109c:	fe0296e3          	bnez	t0,80001088 <UTEST_4MDCT+0x8>

    addi sp, sp, 4
800010a0:	00410113          	addi	sp,sp,4
    jr ra
800010a4:	00008067          	ret

800010a8 <UTEST_CRYPTONIGHT>:

UTEST_CRYPTONIGHT:
#ifdef ENABLE_PAGING
    li a0, 0x7FC10000
#else
    li a0, 0x80400000 // base addr
800010a8:	80400537          	lui	a0,0x80400
#endif
    li a1, 0x200000 // 2M bytes
800010ac:	002005b7          	lui	a1,0x200
    li a3, 524288 // number of iterations
800010b0:	000806b7          	lui	a3,0x80
    li a4, 0x1FFFFC // 2M mask
800010b4:	00200737          	lui	a4,0x200
800010b8:	ffc70713          	addi	a4,a4,-4 # 1ffffc <INITLOCATE-0x7fe00004>
    add a1, a1, a0 // end addr
800010bc:	00a585b3          	add	a1,a1,a0
    li s0, 1 // rand number
800010c0:	00100413          	li	s0,1

    mv a2, a0
800010c4:	00050613          	mv	a2,a0

800010c8 <.INIT_LOOP>:
.INIT_LOOP:
    sw s0, 0(a2)
800010c8:	00862023          	sw	s0,0(a2)

    // xorshift lfsr
    slli s1, s0, 13
800010cc:	00d41493          	slli	s1,s0,0xd
    xor s0, s0, s1
800010d0:	00944433          	xor	s0,s0,s1
    srli s1, s0, 17
800010d4:	01145493          	srli	s1,s0,0x11
    xor s0, s0, s1
800010d8:	00944433          	xor	s0,s0,s1
    slli s1, s0, 5
800010dc:	00541493          	slli	s1,s0,0x5
    xor s0, s0, s1
800010e0:	00944433          	xor	s0,s0,s1

    addi a2, a2, 4
800010e4:	00460613          	addi	a2,a2,4
    bne a2, a1, .INIT_LOOP
800010e8:	feb610e3          	bne	a2,a1,800010c8 <.INIT_LOOP>

    li a2, 0
800010ec:	00000613          	li	a2,0
    li t0, 0
800010f0:	00000293          	li	t0,0

800010f4 <.MAIN_LOOP>:
.MAIN_LOOP:
    // calculate a valid addr from rand number
    and t0, s0, a4
800010f4:	00e472b3          	and	t0,s0,a4
    add t0, a0, t0
800010f8:	005502b3          	add	t0,a0,t0
    // read from it
    lw t0, 0(t0)
800010fc:	0002a283          	lw	t0,0(t0) # 2000000 <INITLOCATE-0x7e000000>
    // xor with last iteration's t0
    xor t0, t0, t1
80001100:	0062c2b3          	xor	t0,t0,t1
    // xor rand number with current t0
    xor s0, s0, t0
80001104:	00544433          	xor	s0,s0,t0

    // get new rand number from xorshift lfsr
    slli s1, s0, 13
80001108:	00d41493          	slli	s1,s0,0xd
    xor s0, s0, s1
8000110c:	00944433          	xor	s0,s0,s1
    srli s1, s0, 17
80001110:	01145493          	srli	s1,s0,0x11
    xor s0, s0, s1
80001114:	00944433          	xor	s0,s0,s1
    slli s1, s0, 5
80001118:	00541493          	slli	s1,s0,0x5
    xor s0, s0, s1
8000111c:	00944433          	xor	s0,s0,s1

    // calculate a valid addr from new rand number
    and t1, s0, a4
80001120:	00e47333          	and	t1,s0,a4
    add t1, a0, t1
80001124:	00650333          	add	t1,a0,t1
    // write t0 to this addr
    sw t0, 0(t1)
80001128:	00532023          	sw	t0,0(t1)
    // save t0 for next iteration
    mv t1, t0
8000112c:	00028313          	mv	t1,t0

    // get new rand number from xorshift lfsr
    slli s1, s0, 13
80001130:	00d41493          	slli	s1,s0,0xd
    xor s0, s0, s1
80001134:	00944433          	xor	s0,s0,s1
    srli s1, s0, 17
80001138:	01145493          	srli	s1,s0,0x11
    xor s0, s0, s1
8000113c:	00944433          	xor	s0,s0,s1
    slli s1, s0, 5
80001140:	00541493          	slli	s1,s0,0x5
    xor s0, s0, s1
80001144:	00944433          	xor	s0,s0,s1

    add a2, a2, 1
80001148:	00160613          	addi	a2,a2,1
    bne a2, a3, .MAIN_LOOP
8000114c:	fad614e3          	bne	a2,a3,800010f4 <.MAIN_LOOP>

    jr ra
80001150:	00008067          	ret
