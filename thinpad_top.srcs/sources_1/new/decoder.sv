`include "header.svh"

module Decoder#(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input wire [DATA_WIDTH-1:0] instr,

    output logic[2:0] instr_type,
    output logic[4:0] instruct,
    output reg[4:0] rs1,
    output reg[4:0] rs2,
    output reg[4:0] rd,
    output logic[3:0] alu_op,
    output reg[DATA_WIDTH-1:0] imm
);
    
    reg [6:0] opcode;
    assign opcode = instr[6:0];
    assign rs1 = instr[19:15];
    assign rs2 = instr[24:20];
    assign rd = instr[11:7];

    always_comb begin
        case(opcode)
            //U
            7'b011_0111: begin
                instr_type = `INSTR_U;
                // LUI
                instruct = `INSTR_LUI;
                imm = {instr[31:12],12'b0};
                alu_op = `ALU_ADD;
            end
            // auipc
            7'b001_0111: begin
                instr_type = `INSTR_U;
                // AUIPC
                instruct = `INSTR_AUIPC;
                imm = {instr[31:12],12'b0};
                alu_op = `ALU_ADD;
            end
            //B
            7'b110_0011: begin
                instr_type = `INSTR_B;

                if(instr[14:12] == 3'b000) instruct = `INSTR_BEQ;// BEQ
                else instruct = `INSTR_BNE;// BNE

                imm[11] = instr[7];
                imm[10:5] = instr[30:25];
                imm[4:1] = instr[12:8];
                imm[0] = 1'b0;
                if(instr[31] == 1'b1) imm[31:12] = 20'b1111_1111_1111_1111_1111;
                else imm[31:12] = 20'b0000_0000_0000_0000_0000;    

                alu_op = `ALU_ADD;        
            end
            // L
            7'b000_0011: begin
                instr_type = `INSTR_L;
                if(instr[14:12] == 3'b000) instruct = `INSTR_LB;// LB
                else if(instr[14:12] == 3'b010) instruct = `INSTR_LW;// LW
                else instruct = `INSTR_NULL;

                imm[11:0] = instr[31:20];

                if(instr[31] == 1'b1) imm[31:12] = 20'hFFFFF;
                else imm[31:12] = 20'b0;
                alu_op = `ALU_ADD;
            end
            // I
            7'b001_0011: begin
                instr_type = `INSTR_I;

                if(instr[14:12] == 3'b000) begin
                    instruct = `INSTR_ADDI;// addi
                    alu_op=`ALU_ADD;
                end
                else if(instr[14:12]==3'b110) begin
                    instruct = `INSTR_ORI;// ori
                    alu_op=`ALU_OR;
                end
                else if(instr[14:12]==3'b111) begin
                    instruct = `INSTR_ANDI;// andi
                    alu_op=`ALU_AND;
                end
                else if(instr[14:12]==3'b001) begin
                    instruct = `INSTR_SLLI;// slli
                    alu_op=`ALU_SLL;
                end
                else begin
                    instruct = `INSTR_SRLI;// srli
                    alu_op=`ALU_SRL;// need more check
                end

                if(instr[31]==1'b1) imm={20'hFFFFF,instr[31:20]};
                else imm={20'h00000,instr[31:20]};
            end

            // Jalr
            7'b110_0111: begin
                instr_type = `INSTR_J;
                instruct = `INSTR_JALR;
                if(instr[31]==1'b1) imm={20'hFFFFF,instr[31:20]};
                else imm={20'h00000,instr[31:20]};
                alu_op = `ALU_ADD;
            end
            // JAL
            7'b110_1111: begin
                instr_type = `INSTR_J;
                instruct = `INSTR_JAL;
                imm[31:20] = (instr[31] == 1) ? 12'hFFF : 12'h000;
                imm[10:1] = instr[30:21];
                imm[11] = instr[20];
                imm[19:12] = instr[19:12];
                imm[0] = 1'b0;
                alu_op = `ALU_ADD;
            end
            // S
            7'b010_0011: begin
                instr_type = `INSTR_S;
                if(instr[14:12]==3'b000) instruct = `INSTR_SB;// sb
                else instruct = `INSTR_SW;// sw
                if(instr[31]==1'b1) imm={20'hFFFFF,instr[31:25],instr[11:7]};
                else imm={20'h00000,instr[31:25],instr[11:7]};
                alu_op = `ALU_ADD;// default: 4'b0001
            end
            // R, EX
            7'b011_0011: begin
                imm = 32'b0;
                if(instr[31:25] == 7'b000_0000)begin
                    // R
                    instr_type = `INSTR_R;
                    if(instr[14:12]==3'b000)begin
                        instruct = `INSTR_ADD; //add
                        alu_op=`ALU_ADD;
                    end
                    else if(instr[14:12]==3'b100)begin
                        instruct = `INSTR_XOR; //xor
                        alu_op=`ALU_XOR;
                    end
                    else if(instr[14:12]==3'b110)begin
                        instruct = `INSTR_OR; //or
                        alu_op=`ALU_OR;
                    end
                    else if(instr[14:12]==3'b111) begin
                        instruct = `INSTR_AND; //and  3'b111
                        alu_op=`ALU_AND;
                    end else begin
                        instruct = `INSTR_NULL;
                        alu_op = `ALU_ADD;
                    end
                end else if(instr[31:25] == 7'b010_0000)begin
                    // EX
                    instr_type = `INSTR_EX;
                    if(instr[14:12] == 3'b111)begin
                        instruct = `INSTR_ANDN; //andn
                        alu_op = `ALU_AND;
                    end
                    else if(instr[14:12] == 3'b100) begin // 3'b100
                        instruct = `INSTR_XNOR; //xnor
                        alu_op = `ALU_XOR;
                    end else begin // 3'b001
                        instruct = `INSTR_NULL;
                        alu_op = `ALU_ADD;
                    end
                end else if(instr[31:25] == 7'b010_0100) begin
                    instr_type = `INSTR_EX;
                    if(instr[14:12]==3'b001)begin
                        instruct = `INSTR_SBCLR; //sll
                        alu_op = `ALU_AND;
                    end else begin // 3'b100
                        instruct = `INSTR_NULL;
                        alu_op = `ALU_ADD;
                    end
                end
            end

            // fence
            7'b000_1111: begin
                imm = 32'b0;
                if (instr[31:25] == 7'b000_0000) begin
                    instr_type = `INSTR_EX;
                    if (instr[14:12] == 3'b001) begin
                        instruct = `INSTR_FENCEI;
                        alu_op = `ALU_ADD;
                    end
                end
            end
                   
            default: begin
                // add zero zero 0
                instr_type = `INSTR_R;
                instruct = `INSTR_ADD;
                imm = 32'b0;
            end
        endcase
    end
endmodule