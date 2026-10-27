// ALU 操作码定义
`define ALU_ADD 4'b0001
`define ALU_AND 4'b0011
`define ALU_OR  4'b0100
`define ALU_XOR 4'b0101
`define ALU_SLL 4'b0111
`define ALU_SRL 4'b1000

// 指令类型定义
`define INSTR_I  3'b000
`define INSTR_S  3'b001
`define INSTR_B  3'b010
`define INSTR_U  3'b011
`define INSTR_R  3'b100
`define INSTR_J  3'b101
`define INSTR_EX 3'b110
`define INSTR_L  3'b111

// 具体指令定义
`define INSTR_ADD   5'd0
`define INSTR_XOR   5'd1
`define INSTR_OR    5'd2
`define INSTR_AND   5'd3
`define INSTR_ADDI  5'd4
`define INSTR_ORI   5'd5
`define INSTR_ANDI  5'd6
`define INSTR_SLLI  5'd7
`define INSTR_SRLI  5'd8
`define INSTR_LW    5'd9
`define INSTR_LB    5'd10
`define INSTR_JALR  5'd11
`define INSTR_SB    5'd12
`define INSTR_SW    5'd13
`define INSTR_BEQ   5'd14
`define INSTR_BNE   5'd15
`define INSTR_LUI   5'd16
`define INSTR_AUIPC 5'd17
`define INSTR_JAL   5'd18
`define INSTR_SBCLR 5'd19
`define INSTR_ANDN  5'd20
`define INSTR_XNOR  5'd21
`define INSTR_FENCEI 5'd22
`define INSTR_NULL  5'd22 // 用于译码错误时的指令

`define INSTR_NOP 32'h0000_0033
`define PC_INIT   32'h8000_0000
