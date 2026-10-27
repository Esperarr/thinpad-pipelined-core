module ALU #(
    parameter DATA_WIDTH = 32
)(
    input wire [DATA_WIDTH-1:0] a,
    input wire [DATA_WIDTH-1:0] b,
    input wire [3:0] op,
    output wire [DATA_WIDTH-1:0] y
);
    reg [31:0] alu_y;

    always_comb begin
        case (op) // 假设 op 是输入的 alu_op_t 类型
            4'b0001: alu_y = a + b;                       // ADD_OP
            4'b0010: alu_y = a - b;                       // SUB_OP
            4'b0011: alu_y = a & b;                       // AND_OP
            4'b0100: alu_y = a | b;                       // OR_OP
            4'b0101: alu_y = a ^ b;                       // XOR_OP
            4'b0110: alu_y = ~a;                          // NOT_OP
            4'b0111: alu_y = a << (b % 32);              // SLL_OP
            4'b1000: alu_y = a >> (b % 32);              // SRL_OP (unsigned)
            4'b1001: alu_y = $unsigned($signed(a) >>> (b % 32)); // SRA_OP (signed)
            4'b1010: alu_y = (a << (b % 32)) | (a >> (32 - (b % 32))); // ROL_OP
            4'b1011: alu_y = (a < b) ? 32'h1 : 32'h0;    // SLT_OP (signed)
            4'b1100: alu_y = ($unsigned(a) < $unsigned(b)) ? 32'h1 : 32'h0; // SLTU_OP (unsigned)
            default: alu_y = a + b;
        endcase
    end
    assign y = alu_y;
endmodule