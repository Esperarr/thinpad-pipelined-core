`include "header.svh"
module pc_mux#(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
)(
    input wire clk_i,
    input wire rst_i,
    input wire if_ack_i,
    input wire if_fetching,
    input wire cache_hit,

    input wire [31:0] exe_pc,
    input wire [31:0] alu_y_pc,
    input wire exe_branch,

    output reg [31:0] pc_out, // register for the next pc
    output reg pc_jump_reg, // register if to jump

    input wire[ADDR_WIDTH-1:0] pc_predict,
    input wire predict_miss
);

logic [31:0] pc_out_reg;

always_comb begin
    if (predict_miss) begin
        pc_out = exe_branch ? alu_y_pc : exe_pc + 4;
    end else if (pc_jump_reg) begin
        pc_out = pc_out_reg;
    end else begin
        pc_out = pc_predict;
    end
end

always_ff @(posedge clk_i or posedge rst_i) begin
    if(rst_i) begin
        pc_out_reg <= `PC_INIT;
        pc_jump_reg <= 0;
    end else begin
        if(cache_hit || (if_fetching && if_ack_i)) begin
            pc_jump_reg <= 0;
        end else if(predict_miss) begin
            pc_jump_reg <= 1;
            pc_out_reg <= exe_branch ? alu_y_pc : exe_pc + 4;
        end
    end
end

endmodule


module pc_predictor#(
    parameter ADDR_WIDTH = 32,
    parameter COL_BIT = 3,
    parameter COL_NUM = 8,
    parameter ROW_BIT = 2,
    parameter ROW_NUM = 4
)(
    input wire clk_i,
    input wire rst_i,
    
    // use pc from if to check table and guess next pc
    input wire [31:0] if_pc,

    input wire [31:0] exe_pc,
    input wire [31:0] alu_y_pc,
    input wire exe_instr_is_branch,
    input wire exe_branch,
    input wire exe_stall,

    output reg [31:0] pc_predict,
    output reg predict_miss
);
    // a table with 2^colbit column and 2^rowbit row, use fifo strategy
    // the destination of branch/jump instrs
    logic [ADDR_WIDTH-1:0] predict_table_to [COL_NUM-1:0][ROW_NUM-1:0];
    // the pc of branch instrs
    logic [ADDR_WIDTH-1-COL_BIT-2:0] predict_table_from [COL_NUM-1:0][ROW_NUM-1:0];
    // valid or not of table elems
    logic predict_table_valid [COL_NUM-1:0][ROW_NUM-1:0];
    // idx of last updated row
    logic [ROW_BIT-1:0] predict_table_oldest_idx [COL_NUM-1:0];

    // check if_pc and give prediction
    logic [COL_BIT-1:0] if_pc_set;
    logic [ADDR_WIDTH-1-COL_BIT-2:0] if_pc_tag;
    always_comb begin
        if_pc_set = if_pc[COL_BIT+1:2];
        if_pc_tag = if_pc[ADDR_WIDTH-1:COL_BIT+2];

        pc_predict = if_pc + 4;
        for (int i=0; i<ROW_NUM; ++i) begin    
            if (predict_table_valid[if_pc_set][i] && if_pc_tag == predict_table_from[if_pc_set][i]) begin
                // hit!
                pc_predict = predict_table_to[if_pc_set][i];
            end
        end
    end

    // check exe_pc and check prediction
    logic exe_hit;
    logic [ROW_BIT-1:0] exe_hit_idx;
    logic [COL_BIT-1:0] exe_pc_set;
    logic [ADDR_WIDTH-1-COL_BIT-2:0] exe_pc_tag;
    logic [ADDR_WIDTH-1:0] exe_next_pc;
    logic [ADDR_WIDTH-1:0] exe_pc_predict;
    always_comb begin
        exe_hit = 0;
        exe_hit_idx = 0;
        exe_pc_set = exe_pc[COL_BIT+1:2];
        exe_pc_tag = exe_pc[ADDR_WIDTH-1:COL_BIT+2];
        exe_pc_predict = exe_pc + 4;
        for (int i=0; i<ROW_NUM; ++i) begin    
            if (predict_table_valid[exe_pc_set][i] && exe_pc_tag == predict_table_from[exe_pc_set][i]) begin
                exe_hit = 1;
                exe_hit_idx = i;
                exe_pc_predict = predict_table_to[exe_pc_set][i];
            end
        end

        predict_miss = 0;
        exe_next_pc = exe_pc + 4;
        if (exe_instr_is_branch && exe_branch) begin
            exe_next_pc = alu_y_pc;
        end
        if (exe_next_pc != exe_pc_predict) begin
            predict_miss = 1;
        end
    end

    // reset logic and table update logic
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            // reset validation and last update of table
            for (int col = 0; col < COL_NUM; col++) begin
                for (int row = 0; row < ROW_NUM; row++) begin
                    predict_table_valid[col][row] = 0;
                end
                predict_table_oldest_idx[col] = 0;
            end
        end else begin
            // check exe predict miss
            if (predict_miss && !exe_stall) begin
                if (exe_hit) begin
                    // update current valid table entry
                    predict_table_to[exe_pc_set][exe_hit_idx] <= exe_next_pc;
                end else begin
                    // rewrite table entry
                    predict_table_from[exe_pc_set][predict_table_oldest_idx[exe_pc_set]] <= exe_pc_tag;
                    predict_table_to[exe_pc_set][predict_table_oldest_idx[exe_pc_set]] <= exe_next_pc;
                    predict_table_valid[exe_pc_set][predict_table_oldest_idx[exe_pc_set]] <= 1;
                    predict_table_oldest_idx[exe_pc_set] <= predict_table_oldest_idx[exe_pc_set] + 1;
                end
            end
        end
    end
endmodule
