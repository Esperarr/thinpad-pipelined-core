`default_nettype none

module regfile#(
    parameter DATA_WIDTH = 32
)(
    input wire clk,
    input wire reset,

    input wire[4:0] waddr,
    input wire[DATA_WIDTH-1:0] wdata,
    input wire we,

    input wire[4:0] raddr_a,
    input wire[4:0] raddr_b,
    output reg [DATA_WIDTH-1:0] rdata_a,
    output reg [DATA_WIDTH-1:0] rdata_b

);
    // 寄存器组
    reg [31:0] regs [0:31];

    assign rdata_a = regs[raddr_a];
    assign rdata_b = regs[raddr_b];

    always_ff@(posedge clk or posedge reset) begin
        if(reset) for(int i = 0; i < 32; i = i + 1) regs[i] <= 32'b0;
        else begin
            if(we) begin
                if(waddr != 0 ) regs[waddr] <= wdata;
            end 
        end
    end
endmodule